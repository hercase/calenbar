import CalenbarCore
import Foundation
import Observation

/// Where "Open event" / "Respond…" take you.
enum EventDestination: String, Codable, CaseIterable {
    /// Google events in Google Calendar on the web, everything else in Calendar.app.
    case automatic
    case calendarApp
    case googleWeb
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
    var showMonthCalendar: Bool { didSet { store(showMonthCalendar, .showMonthCalendar) } }
    var openEventsIn: EventDestination { didSet { store(openEventsIn, .openEventsIn) } }
    /// Bundle id of the browser for meeting links; empty means the system default browser.
    var meetingBrowserID: String { didSet { store(meetingBrowserID, .meetingBrowserID) } }
    var preferNativeMeetingApps: Bool { didSet { store(preferNativeMeetingApps, .preferNativeMeetingApps) } }
    var flashEnabled: Bool { didSet { store(flashEnabled, .flashEnabled) } }
    var flashFromFiveMinutes: Bool { didSet { store(flashFromFiveMinutes, .flashFromFiveMinutes) } }
    var attentionSound: Bool { didSet { store(attentionSound, .attentionSound) } }

    var notificationsEnabled: Bool { didSet { store(notificationsEnabled, .notificationsEnabled) } }
    var notifyLeadMinutes: Int { didSet { store(notifyLeadMinutes, .notifyLeadMinutes) } }
    var alertEnabled: Bool { didSet { store(alertEnabled, .alertEnabled) } }
    var alertLeadMinutes: Int { didSet { store(alertLeadMinutes, .alertLeadMinutes) } }
    var alertOnlyWithLink: Bool { didSet { store(alertOnlyWithLink, .alertOnlyWithLink) } }

    var disabledCalendars: [CalendarPurpose: Set<String>] { didSet { store(disabledCalendars, .disabledCalendars) } }
    var hiddenKeys: Set<String> { didSet { store(hiddenKeys, .hiddenKeys) } }
    var mutedKeys: Set<String> { didSet { store(mutedKeys, .mutedKeys) } }
    /// Clocks shown in the panel footer; only this many fit on its single line.
    static let maxWorldClocks = 3
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
        case titleRule, showMonthCalendar, openEventsIn, meetingBrowserID, preferNativeMeetingApps, flashEnabled,
            flashFromFiveMinutes, attentionSound
        case notificationsEnabled, notifyLeadMinutes, alertEnabled, alertLeadMinutes, alertOnlyWithLink
        case disabledCalendars, hiddenKeys, mutedKeys, worldClocks, showClocksInPanel, showClocksInEventDetails
    }

    static let notifyLeadOptions = [0, 1, 2, 5, 10]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        titleRule = Self.load(.titleRule, from: defaults) ?? .switchBeforeNextStarts
        showMonthCalendar = Self.load(.showMonthCalendar, from: defaults) ?? false
        openEventsIn = Self.load(.openEventsIn, from: defaults) ?? .automatic
        meetingBrowserID = Self.load(.meetingBrowserID, from: defaults) ?? ""
        preferNativeMeetingApps = Self.load(.preferNativeMeetingApps, from: defaults) ?? true
        flashEnabled = Self.load(.flashEnabled, from: defaults) ?? true
        flashFromFiveMinutes = Self.load(.flashFromFiveMinutes, from: defaults) ?? true
        attentionSound = Self.load(.attentionSound, from: defaults) ?? false
        notificationsEnabled = Self.load(.notificationsEnabled, from: defaults) ?? true
        notifyLeadMinutes = Self.load(.notifyLeadMinutes, from: defaults) ?? 1
        alertEnabled = Self.load(.alertEnabled, from: defaults) ?? true
        alertLeadMinutes = Self.load(.alertLeadMinutes, from: defaults) ?? 0
        alertOnlyWithLink = Self.load(.alertOnlyWithLink, from: defaults) ?? true
        disabledCalendars = Self.load(.disabledCalendars, from: defaults) ?? [:]
        hiddenKeys = Self.load(.hiddenKeys, from: defaults) ?? []
        mutedKeys = Self.load(.mutedKeys, from: defaults) ?? []
        worldClocks = Self.load(.worldClocks, from: defaults) ?? []
        showClocksInPanel = Self.load(.showClocksInPanel, from: defaults) ?? true
        showClocksInEventDetails = Self.load(.showClocksInEventDetails, from: defaults) ?? true
        pruneExpiredEventKeys()
        // "Hide from menu bar" and "mute" were merged into a single Skip.
        if !hiddenKeys.isEmpty {
            mutedKeys.formUnion(hiddenKeys)
            hiddenKeys = []
        }
    }

    var eventFilter: EventFilter {
        EventFilter(disabledCalendars: disabledCalendars, hiddenKeys: hiddenKeys, mutedKeys: mutedKeys)
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
        hiddenKeys = hiddenKeys.filter(isFresh)
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
