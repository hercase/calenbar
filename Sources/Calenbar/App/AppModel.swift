import AppKit
import CalenbarCore
import Foundation
import Observation

/// Wires the services together and derives what every surface (menu bar, panel, alerts) shows.
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let calendar: CalendarService
    let clock: MinuteClock
    let updater = Updater()
    /// Set by the app delegate once the scheduler exists; Settings reads the permission state from it.
    var notifications: NotificationScheduler?
    /// Set by the app delegate; Settings uses it for the test alert.
    var alerts: FullScreenAlertController?
    /// Set by the app delegate; Settings uses it to preview the red and yellow flashes.
    var previewFlash: ((FlashPreview) -> Void)?
    /// The flash preview running right now, so Settings can show which button is active.
    var flashPreviewing: FlashPreview?
    /// Whether the running preview is in its "on" beat, so Settings' mock bar flashes in step with the real one.
    var flashPhaseOn = false
    /// Set by the app delegate; the panel's clock nudge opens Settings on the Time Zones page.
    var openTimeZoneSettings: (() -> Void)?
    @ObservationIgnored private var suggestionCache: (key: String, value: [ClockSuggestion])?

    init(settings: AppSettings, calendar: CalendarService, clock: MinuteClock) {
        self.settings = settings
        self.calendar = calendar
        self.clock = clock
    }

    var now: Date { clock.now }

    /// Time zones the next 60 days of meetings (and the last 30) point at that have no clock yet.
    /// Remembered until the calendar reloads, since the panel asks on every redraw.
    var clockSuggestions: [ClockSuggestion] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let existing = Set(settings.worldClocks.map(\.timeZoneID))
        let dismissed = settings.dismissedClockSuggestions
        let key = [
            "\(calendar.lastReload?.timeIntervalSinceReferenceDate ?? 0)", "\(today.timeIntervalSinceReferenceDate)",
            existing.sorted().joined(separator: ","),
            dismissed.map { "\($0.key)=\($0.value.date.timeIntervalSinceReferenceDate)" }.sorted().joined(separator: ","),
        ].joined(separator: "|")
        if let cached = suggestionCache, cached.key == key { return cached.value }
        let start = cal.date(byAdding: .day, value: -ClockSuggestions.lookBackDays, to: today) ?? today
        let end = cal.date(byAdding: .day, value: ClockSuggestions.lookAheadDays, to: today) ?? today
        let value = ClockSuggestions.suggest(
            events: calendar.cachedEvents(from: start, to: end), now: now, existing: existing, dismissed: dismissed)
        suggestionCache = (key, value)
        return value
    }

    /// The event shown in the menu bar, or nil when nothing qualifies.
    var titleEvent: CalendarEvent? {
        let candidates = settings.eventFilter.apply(calendar.upcoming, for: .title)
        return TitleSelector(rule: settings.titleRule, horizon: settings.titleHorizon).select(from: candidates, now: now)
    }

    /// The meeting right behind the ongoing one in the menu bar, for the yellow warning.
    func titleFollowUp(to shown: CalendarEvent) -> CalendarEvent? {
        TitleSelector(rule: settings.titleRule, horizon: settings.titleHorizon)
            .followUp(to: shown, in: events(for: .title), now: now)
    }

    /// The meeting the global shortcut and "Join Next Meeting" open.
    var nextMeeting: CalendarEvent? {
        MeetingPicker.next(titleEvent: titleEvent, candidates: events(for: .title), now: now)
    }

    /// Joins it, or beeps when there's nothing to join.
    func joinNextMeeting() {
        guard let event = nextMeeting, let link = event.meetingLink else {
            NSSound.beep()
            return
        }
        MeetingOpener.open(link, event: event)
    }

    /// The standing room from Settings, when the text is a link.
    var personalRoom: URL? {
        let text = settings.personalRoomURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), url.scheme != nil, url.host != nil else { return nil }
        return url
    }

    /// Opens the standing room (through its app when it's a known service) and puts the link on the
    /// clipboard, ready to paste into the chat.
    func startPersonalRoom() {
        guard let url = personalRoom else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        if let link = MeetingLinkDetector.detect(url: url, location: nil, notes: nil) {
            MeetingOpener.open(link)
        } else {
            MeetingOpener.openInBrowser(url)
        }
    }

    /// Opens the service's instant-meeting page in the user's meeting browser.
    func startNewMeeting(_ provider: MeetingProvider) {
        if let url = provider.newMeetingURL {
            MeetingOpener.openInBrowser(url)
        }
    }

    /// What the menu bar prints for an event: its title, or a stand-in while the screen is shared.
    func menuBarTitle(for event: CalendarEvent) -> String {
        settings.hideTitlesInMenuBar ? TitleFormatter.privateTitle(event) : TitleFormatter.displayTitle(event)
    }

    /// Calendars whose days are tinted as holidays: the ones named like it, adjusted by the user's choices.
    var holidayCalendarIDs: Set<String> {
        var ids = calendar.holidayLookingIDs
        for (id, isHolidays) in settings.holidayCalendarChoices {
            if isHolidays { ids.insert(id) } else { ids.remove(id) }
        }
        return ids
    }

    func events(for purpose: CalendarPurpose) -> [CalendarEvent] {
        settings.eventFilter.apply(calendar.upcoming, for: purpose)
    }

    func listEvents(on day: Date) -> [CalendarEvent] {
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        // Days inside the loaded window come from memory, even when they're empty.
        let source =
            calendar.loadedRange.contains(start) && calendar.loadedRange.contains(end.addingTimeInterval(-1))
            ? calendar.upcoming
            : calendar.cachedEvents(from: start, to: end)
        return settings.eventFilter
            .apply(source, for: .list)
            .filter { $0.start < end && $0.end > start }
    }

    /// Opens the event where the user answers invitations: Google Calendar on the web for Google
    /// events (by default), Calendar.app otherwise.
    func openEvent(_ event: CalendarEvent) {
        let googleURL = GoogleCalendarLink.url(
            externalID: event.externalID,
            calendarTitle: event.calendarTitle,
            start: event.start,
            isRecurring: event.isRecurring
        )
        switch (settings.openEventsIn, googleURL) {
        case (.automatic, let url?), (.googleWeb, let url?):
            MeetingOpener.openInBrowser(url, event: event)
        default:
            calendar.openInCalendar(event)
        }
    }

    /// Where `openEvent` takes this event, for button labels ("Answer in Google Calendar").
    func eventDestinationName(_ event: CalendarEvent) -> String {
        let isGoogle = GoogleCalendarLink.isGoogleEvent(externalID: event.externalID)
        switch settings.openEventsIn {
        case .calendarApp: return String(localized: "Calendar")
        case .automatic, .googleWeb: return isGoogle ? "Google Calendar" : String(localized: "Calendar")
        }
    }

    func isSkipped(_ event: CalendarEvent) -> Bool {
        settings.mutedKeys.contains(event.key)
    }

    /// Focus fills the gap and stays off the menu bar and the alerts.
    func blockFocus(from start: Date, to end: Date) {
        block(String(localized: "Focus"), from: start, to: end)
    }

    /// Lunch covers at most an hour inside the gap, with the same quiet treatment as focus.
    func blockLunch(from start: Date, to end: Date) {
        block(String(localized: "Lunch"), from: start, to: end)
    }

    /// Opens a new event with the time filled in. Nothing is saved until the user says so.
    /// Google Calendar on the web when that's where events open; Calendar.app otherwise.
    func draftMeeting(from start: Date, to end: Date) {
        let title = String(localized: "Meeting")
        let template = GoogleCalendarLink.templateURL(title: title, start: start, end: end, timeZone: .current)
        if settings.openEventsIn == .googleWeb, let template {
            MeetingOpener.openInBrowser(template)
            return
        }
        calendar.openDraft(title: title, start: start, end: end)
    }

    private func block(_ title: String, from start: Date, to end: Date) {
        let key = calendar.createQuietBlock(title: title, start: start, end: end, calendarID: settings.blockCalendarID)
        guard let key else {
            NSSound.beep()
            return
        }
        settings.quietKeys.insert(key)
    }
}

/// Re-runs `apply` whenever any observable value it read changes.
@MainActor
func observeContinuously(_ apply: @escaping @MainActor () -> Void) {
    withObservationTracking {
        apply()
    } onChange: {
        Task { @MainActor in observeContinuously(apply) }
    }
}

/// The two menu bar flashes Settings can preview.
enum FlashPreview {
    case red, yellow

    /// A touch deeper than systemRed so the white title clears 4.5:1; black on systemYellow is already far above it.
    var nsColor: NSColor {
        switch self {
        case .red: NSColor(red: 0.84, green: 0, blue: 0.08, alpha: 1)
        case .yellow: .systemYellow
        }
    }
}
