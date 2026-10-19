import AppKit
import CalenbarCore
import EventKit
import Network
import Observation

struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let colorHex: String
    let sourceTitle: String
    /// True for calendars synced from an account (Google, Exchange, iCloud); false for local,
    /// subscribed and birthday calendars, which exist on every Mac and prove nothing.
    let isFromAccount: Bool
}

/// Reads events from the macOS Calendar database and keeps them fresh.
@MainActor
@Observable
final class CalendarService {
    enum Access {
        case notDetermined
        case granted
        case denied
    }

    /// Today through the next two weeks; enough for the title, the list and notifications.
    private(set) var upcoming: [CalendarEvent] = []
    private(set) var calendars: [CalendarInfo] = []
    private(set) var access: Access
    /// When events were last read from the system calendar database.
    private(set) var lastReload: Date?

    /// Whether any calendar comes from a signed-in account. Without one, the empty panel is almost
    /// always "the Google account isn't added to the Mac yet", not "a free week".
    var hasAccountCalendar: Bool { calendars.contains(where: \.isFromAccount) }

    @ObservationIgnored private let store = EKEventStore()
    /// Maps our per-occurrence id to EventKit's identifier, for "Open in Calendar". Also holds ids of
    /// occurrences fetched for other days, so a reload must not clear it; a few hundred short strings.
    @ObservationIgnored private var eventIdentifiers: [String: String] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var safetyTimer: Timer?
    @ObservationIgnored private let network = NWPathMonitor()
    /// Previews answer date-range queries from `upcoming` instead of EventKit.
    @ObservationIgnored private var isFixture = false
    /// The span `upcoming` covers, so callers know when a day needs its own query.
    @ObservationIgnored private(set) var loadedRange: Range<Date> = Date.distantPast..<Date.distantPast
    /// Month grids ask for the same six weeks on every click; one EventKit query per reload is enough.
    @ObservationIgnored private var rangeCache: [String: [CalendarEvent]] = [:]
    @ObservationIgnored private var pendingReload: Task<Void, Never>?
    @ObservationIgnored private var wasOnline = true
    /// Calendars whose name says "holidays" in some language; the user can override per calendar.
    private(set) var holidayLookingIDs: Set<String> = []

    /// Fixed data for previews: no EventKit, no observers, no timers.
    init(fixture: [CalendarEvent], calendars: [CalendarInfo], access: Access = .granted) {
        self.access = access
        isFixture = true
        upcoming = fixture
        self.calendars = calendars
        holidayLookingIDs = Set(calendars.filter { DayOffDetector.looksLikeHolidayCalendar($0.title) }.map(\.id))
        loadedRange = Date.distantPast..<Date.distantFuture
        lastReload = Date()
    }

    init() {
        access = Self.currentAccess()
        // EventKit posts this several times per sync; one reload a second later covers the burst.
        observers.append(
            NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleReload() }
            })
        // Synced accounts can go stale after sleep or a network switch; nudge them to refresh.
        observers.append(
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshSources() }
            })
        // Only the moment the network comes back matters, not every interface or DNS change.
        network.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let cameBack = online && !self.wasOnline
                self.wasOnline = online
                if cameBack {
                    self.refreshSources()
                }
            }
        }
        network.start(queue: .global(qos: .utility))
        // macOS syncs Google/Exchange on its own schedule; nudging it often keeps new invites showing up quickly.
        let timer = Timer(timeInterval: 5 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSources() }
        }
        timer.tolerance = 60  // Lets macOS batch the wake-up with others.
        RunLoop.main.add(timer, forMode: .common)
        safetyTimer = timer
        reload()
    }

    /// Asks macOS to sync remote calendars (Google, Exchange…) now. The sync is asynchronous: anything
    /// new arrives through `EKEventStoreChanged`, so only a deferred reload is scheduled, which also
    /// re-anchors the window on today after midnight.
    func refreshSources() {
        guard access == .granted else { return }
        store.refreshSourcesIfNecessary()
        scheduleReload()
    }

    /// One reload shortly, however many times it is asked for in the meantime.
    private func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        access = Self.currentAccess()
        reload()
    }

    func reload() {
        guard access == .granted else {
            upcoming = []
            calendars = []
            return
        }
        let freshCalendars = store.calendars(for: .event)
            .map { calendar in
                CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    colorHex: calendar.color.hexString,
                    sourceTitle: calendar.source.title,
                    isFromAccount: [.calDAV, .exchange, .mobileMe].contains(calendar.source.sourceType)
                )
            }
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }

        lastReload = Date()
        rangeCache = [:]
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 14, to: startOfToday) ?? startOfToday
        loadedRange = startOfToday..<end
        let freshEvents = events(from: startOfToday, to: end)
        // Assign only on change: every observer (status item, notifications, alerts) re-runs on assignment,
        // and the 5-minute nudge usually finds nothing new.
        if freshCalendars != calendars {
            calendars = freshCalendars
            holidayLookingIDs = Set(freshCalendars.filter { DayOffDetector.looksLikeHolidayCalendar($0.title) }.map(\.id))
        }
        if freshEvents != upcoming {
            upcoming = freshEvents
        }
    }

    /// `events(from:to:)` with the answer kept until the next reload. Reading `upcoming` here makes
    /// SwiftUI callers re-render when a reload brings changes.
    func cachedEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        _ = upcoming
        let key = "\(start.timeIntervalSinceReferenceDate)|\(end.timeIntervalSinceReferenceDate)"
        if let hit = rangeCache[key] {
            return hit
        }
        let fetched = events(from: start, to: end)
        rangeCache[key] = fetched
        return fetched
    }

    func events(from start: Date, to end: Date) -> [CalendarEvent] {
        guard access == .granted else { return [] }
        if isFixture {
            return upcoming.filter { $0.start < end && $0.end > start }
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        // Declined copies go before deduplication: a declined invite must not resurface through
        // the team calendar's copy, nor hide it.
        let events = store.events(matching: predicate)
            .map(makeEvent)
            .filter { !$0.isDeclined }
            .sorted { $0.start < $1.start }
        return CalendarEvent.deduplicated(events)
    }

    func openInCalendar(_ event: CalendarEvent) {
        guard let identifier = eventIdentifiers[event.id],
            let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "ical://ekevent/\(encoded)?method=show&options=more")
        else {
            openCalendarApp()
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openCalendarApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }

    static func openInternetAccountsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private func makeEvent(_ event: EKEvent) -> CalendarEvent {
        let identifier = event.eventIdentifier ?? UUID().uuidString
        let id = "\(identifier)|\(Int(event.startDate.timeIntervalSince1970))"
        eventIdentifiers[id] = identifier

        let participants = event.attendees ?? []
        let currentUser = participants.first { $0.isCurrentUser }
        let organizerURL = event.organizer?.url
        let attendees = participants.map { participant in
            Attendee(
                name: participant.name,
                email: Self.email(from: participant.url),
                status: Self.status(participant.participantStatus),
                kind: Self.kind(participant.participantType),
                isCurrentUser: participant.isCurrentUser,
                isOrganizer: organizerURL != nil && participant.url == organizerURL
            )
        }
        return CalendarEvent(
            id: id,
            externalID: event.calendarItemExternalIdentifier ?? identifier,
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarID: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            calendarColorHex: event.calendar.color.hexString,
            isDeclined: currentUser?.participantStatus == .declined,
            hasOtherAttendees: participants.contains { !$0.isCurrentUser },
            url: event.url,
            location: event.location,
            notes: event.notes,
            attendees: attendees,
            myStatus: currentUser.map { Self.status($0.participantStatus) } ?? .unknown,
            isRecurring: event.hasRecurrenceRules
        )
    }

    private static func email(from url: URL) -> String? {
        guard url.scheme == "mailto" else { return nil }
        return url.absoluteString.replacingOccurrences(of: "mailto:", with: "").removingPercentEncoding
    }

    private static func status(_ status: EKParticipantStatus) -> ParticipationStatus {
        switch status {
        case .pending, .delegated: .pending
        case .accepted, .completed, .inProcess: .accepted
        case .tentative: .tentative
        case .declined: .declined
        default: .unknown
        }
    }

    private static func kind(_ type: EKParticipantType) -> Attendee.Kind {
        switch type {
        case .room: .room
        case .resource: .resource
        case .group: .group
        default: .person
        }
    }
}
