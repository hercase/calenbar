import CalenbarCore
import Foundation
import Observation

/// Where "Open in…" and "Answer in…" take you.
enum EventDestination: String, Codable, CaseIterable {
    /// Google events in Google Calendar on the web, everything else in Calendar.app.
    case automatic
    case calendarApp
    case googleWeb
}

/// Room for the title on displays without a notch (a notched screen fits itself to the space right of it).
enum TitleWidth: String, Codable, CaseIterable {
    /// As wide as the apps in use allow: shrinks when macOS hides the item for colliding with their menus.
    case automatic
    case short, medium, long

    var points: Double? {
        switch self {
        case .automatic: nil
        case .short: 120
        case .medium: 200
        case .long: 320
        }
    }
}

/// How the alert takes the screen when a meeting starts.
enum AlertStyle: String, Codable, CaseIterable {
    /// Whole screen, blurred: impossible to miss.
    case fullScreen
    /// A small card in the top-right corner, over every Space and full-screen app.
    case card
}

/// Where the alert card sits. Top left is where the eye starts; bottom corners stay clear of macOS
/// notifications, which stack top-right.
enum AlertCorner: String, Codable, CaseIterable {
    case topRight, bottomRight, topLeft, bottomLeft
}

struct WorldClock: Codable, Hashable, Identifiable {
    var id = UUID()
    var timeZoneID: String
    var name: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

/// User preferences, persisted to `UserDefaults` as soon as they change.
@MainActor
@Observable
final class AppSettings {
    var titleRule: TitleRule { didSet { store(titleRule, .titleRule) } }
    /// How far ahead the menu bar looks for the next event.
    var titleHorizon: TitleHorizon { didSet { store(titleHorizon, .titleHorizon) } }
    var titleWidth: TitleWidth { didSet { store(titleWidth, .titleWidth) } }
    var showMonthCalendar: Bool { didSet { store(showMonthCalendar, .showMonthCalendar) } }
    var showWeekNumbers: Bool { didSet { store(showWeekNumbers, .showWeekNumbers) } }
    /// Hovering the menu bar item shows the event's card without opening the panel.
    var hoverPreview: Bool { didSet { store(hoverPreview, .hoverPreview) } }
    /// Screen-sharing mode: the menu bar says "Meeting" instead of the event's title.
    var hideTitlesInMenuBar: Bool { didSet { store(hideTitlesInMenuBar, .hideTitlesInMenuBar) } }
    /// System-wide shortcut that joins the next meeting; nil when none is recorded.
    var joinShortcut: KeyShortcut? { didSet { store(joinShortcut, .joinShortcut) } }
    var openEventsIn: EventDestination { didSet { store(openEventsIn, .openEventsIn) } }
    /// Bundle id of the browser for meeting links; empty means the system default browser.
    var meetingBrowserID: String { didSet { store(meetingBrowserID, .meetingBrowserID) } }
    var preferNativeMeetingApps: Bool { didSet { store(preferNativeMeetingApps, .preferNativeMeetingApps) } }
    /// The user's standing meeting room (a fixed Meet, a Zoom personal meeting id): "New Meeting › My Room".
    var personalRoomURL: String { didSet { store(personalRoomURL, .personalRoomURL) } }
    var flashEnabled: Bool { didSet { store(flashEnabled, .flashEnabled) } }
    var flashFromFiveMinutes: Bool { didSet { store(flashFromFiveMinutes, .flashFromFiveMinutes) } }
    var attentionSound: Bool { didSet { store(attentionSound, .attentionSound) } }

    var notificationsEnabled: Bool { didSet { store(notificationsEnabled, .notificationsEnabled) } }
    var notifyLeadMinutes: Int { didSet { store(notifyLeadMinutes, .notifyLeadMinutes) } }
    var alertEnabled: Bool { didSet { store(alertEnabled, .alertEnabled) } }
    var alertLeadMinutes: Int { didSet { store(alertLeadMinutes, .alertLeadMinutes) } }
    var alertOnlyWithLink: Bool { didSet { store(alertOnlyWithLink, .alertOnlyWithLink) } }
    var alertStyle: AlertStyle { didSet { store(alertStyle, .alertStyle) } }
    var alertCorner: AlertCorner { didSet { store(alertCorner, .alertCorner) } }
    /// Display for the full-screen alert (`NSScreenNumber`); nil means the screen under the pointer.
    var alertDisplayID: UInt32? { didSet { store(alertDisplayID, .alertDisplayID) } }

    var disabledCalendars: [CalendarPurpose: Set<String>] { didSet { store(disabledCalendars, .disabledCalendars) } }
    /// Per-calendar answer to "is this a holidays calendar?", when the user overrode the name-based default.
    var holidayCalendarChoices: [String: Bool] { didSet { store(holidayCalendarChoices, .holidayCalendarChoices) } }
    /// Keys of skipped occurrences.
    var mutedKeys: Set<String> { didSet { store(mutedKeys, .mutedKeys) } }
    /// Clocks shown in the panel, one row each; more than this and the panel gets tall.
    static let maxWorldClocks = 5
    var worldClocks: [WorldClock] { didSet { store(worldClocks, .worldClocks) } }
    var showClocksInPanel: Bool { didSet { store(showClocksInPanel, .showClocksInPanel) } }
    var showClocksInEventDetails: Bool { didSet { store(showClocksInEventDetails, .showClocksInEventDetails) } }

    /// Backed by the launchd agent, not UserDefaults; re-read after each change in case macOS refused it.
    var launchAtLogin: Bool = LoginLaunch.isEnabled {
        didSet {
            guard launchAtLogin != LoginLaunch.isEnabled else { return }
            LoginLaunch.setEnabled(launchAtLogin)
            launchAtLogin = LoginLaunch.isEnabled
        }
    }

    private enum Key: String {
        case titleRule, titleHorizon, titleWidth, hoverPreview, showMonthCalendar, showWeekNumbers, hideTitlesInMenuBar,
            joinShortcut,
            openEventsIn,
            meetingBrowserID, preferNativeMeetingApps, personalRoomURL, flashEnabled, flashFromFiveMinutes, attentionSound
        case notificationsEnabled, notifyLeadMinutes, alertEnabled, alertLeadMinutes, alertOnlyWithLink, alertDisplayID,
            alertStyle, alertCorner
        case disabledCalendars, holidayCalendarChoices, hiddenKeys, mutedKeys, worldClocks, showClocksInPanel,
            showClocksInEventDetails
    }

    static let notifyLeadOptions = [0, 1, 2, 5, 10]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        titleRule = Self.load(.titleRule, from: defaults) ?? .switchBeforeNextStarts
        titleHorizon = Self.load(.titleHorizon, from: defaults) ?? .today
        titleWidth = Self.load(.titleWidth, from: defaults) ?? .automatic
        hoverPreview = Self.load(.hoverPreview, from: defaults) ?? true
        showMonthCalendar = Self.load(.showMonthCalendar, from: defaults) ?? false
        showWeekNumbers = Self.load(.showWeekNumbers, from: defaults) ?? false
        hideTitlesInMenuBar = Self.load(.hideTitlesInMenuBar, from: defaults) ?? false
        // Never set → the default; set to nothing (stored null) → none.
        let storedShortcut: KeyShortcut?? = Self.load(.joinShortcut, from: defaults)
        joinShortcut = storedShortcut.map { $0 } ?? .defaultJoin
        openEventsIn = Self.load(.openEventsIn, from: defaults) ?? .automatic
        meetingBrowserID = Self.load(.meetingBrowserID, from: defaults) ?? ""
        preferNativeMeetingApps = Self.load(.preferNativeMeetingApps, from: defaults) ?? true
        personalRoomURL = Self.load(.personalRoomURL, from: defaults) ?? ""
        flashEnabled = Self.load(.flashEnabled, from: defaults) ?? true
        flashFromFiveMinutes = Self.load(.flashFromFiveMinutes, from: defaults) ?? true
        attentionSound = Self.load(.attentionSound, from: defaults) ?? false
        notificationsEnabled = Self.load(.notificationsEnabled, from: defaults) ?? true
        notifyLeadMinutes = Self.load(.notifyLeadMinutes, from: defaults) ?? 1
        // On by default as the corner card; the full-screen takeover is the opt-in step up.
        alertEnabled = Self.load(.alertEnabled, from: defaults) ?? true
        alertLeadMinutes = Self.load(.alertLeadMinutes, from: defaults) ?? 0
        alertOnlyWithLink = Self.load(.alertOnlyWithLink, from: defaults) ?? true
        // The gentle one first; the takeover is a step up for those who want it.
        alertStyle = Self.load(.alertStyle, from: defaults) ?? .card
        alertCorner = Self.load(.alertCorner, from: defaults) ?? .topLeft
        let storedDisplay: UInt32?? = Self.load(.alertDisplayID, from: defaults)
        alertDisplayID = storedDisplay.flatMap { $0 }
        disabledCalendars = Self.load(.disabledCalendars, from: defaults) ?? [:]
        holidayCalendarChoices = Self.load(.holidayCalendarChoices, from: defaults) ?? [:]
        mutedKeys = Self.load(.mutedKeys, from: defaults) ?? []
        worldClocks = Self.load(.worldClocks, from: defaults) ?? []
        showClocksInPanel = Self.load(.showClocksInPanel, from: defaults) ?? true
        showClocksInEventDetails = Self.load(.showClocksInEventDetails, from: defaults) ?? true
        // 0.1.0 had separate "hide from menu bar" and "mute" sets; both became Skip.
        if let legacyHidden: Set<String> = Self.load(.hiddenKeys, from: defaults) {
            mutedKeys.formUnion(legacyHidden)
            defaults.removeObject(forKey: Key.hiddenKeys.rawValue)
        }
        pruneExpiredEventKeys()
    }

    var eventFilter: EventFilter {
        EventFilter(disabledCalendars: disabledCalendars, mutedKeys: mutedKeys)
    }

    func isEnabled(calendarID: String, for purpose: CalendarPurpose) -> Bool {
        !(disabledCalendars[purpose]?.contains(calendarID) ?? false)
    }

    func setEnabled(_ enabled: Bool, calendarID: String, for purpose: CalendarPurpose) {
        var ids = disabledCalendars[purpose] ?? []
        if enabled {
            ids.remove(calendarID)
        } else {
            ids.insert(calendarID)
        }
        disabledCalendars[purpose] = ids
    }

    /// Holiday calendars are recognised by name; this is the user's say over that guess.
    func isHolidayCalendar(_ info: CalendarInfo) -> Bool {
        holidayCalendarChoices[info.id] ?? DayOffDetector.looksLikeHolidayCalendar(info.title)
    }

    func setHolidays(_ isHolidays: Bool, calendar info: CalendarInfo) {
        if isHolidays == DayOffDetector.looksLikeHolidayCalendar(info.title) {
            holidayCalendarChoices.removeValue(forKey: info.id)
        } else {
            holidayCalendarChoices[info.id] = isHolidays
        }
    }

    /// Adds a clock unless one for that time zone already exists.
    func addWorldClock(timeZoneID: String, name: String) {
        guard !worldClocks.contains(where: { $0.timeZoneID == timeZoneID }), worldClocks.count < Self.maxWorldClocks else {
            return
        }
        worldClocks.append(WorldClock(timeZoneID: timeZoneID, name: name))
    }

    /// Skip = the event disappears from the menu bar and never alerts; it stays (dimmed) in the list.
    func toggleSkipped(_ event: CalendarEvent) {
        mutedKeys.formSymmetricDifference([event.key])
    }

    /// Event keys end in the occurrence's start timestamp; forget entries a month after the event.
    private func pruneExpiredEventKeys() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3_600).timeIntervalSince1970
        let isFresh: (String) -> Bool = { key in
            guard let stamp = key.split(separator: "|").last.flatMap({ TimeInterval($0) }) else { return true }
            return stamp >= cutoff
        }
        mutedKeys = mutedKeys.filter(isFresh)
    }

    private func store<Value: Encodable>(_ value: Value, _ key: Key) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    private static func load<Value: Decodable>(_ key: Key, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }
}
