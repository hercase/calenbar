import Foundation

/// Where an event is about to be used. Each purpose has its own calendar toggles in Settings.
public enum CalendarPurpose: String, CaseIterable, Codable, Sendable {
    case list
    case title
    case notify
    case alert
}

public struct EventFilter: Sendable {
    public var disabledCalendars: [CalendarPurpose: Set<String>]
    public var hiddenKeys: Set<String>
    public var mutedKeys: Set<String>

    public init(
        disabledCalendars: [CalendarPurpose: Set<String>] = [:],
        hiddenKeys: Set<String> = [],
        mutedKeys: Set<String> = []
    ) {
        self.disabledCalendars = disabledCalendars
        self.hiddenKeys = hiddenKeys
        self.mutedKeys = mutedKeys
    }

    public func apply(_ events: [CalendarEvent], for purpose: CalendarPurpose) -> [CalendarEvent] {
        let disabled = disabledCalendars[purpose] ?? []
        return events.filter { event in
            guard !event.isDeclined, !disabled.contains(event.calendarID) else { return false }
            switch purpose {
            case .list:
                // Skipped/hidden events stay in the list (dimmed) so they can be brought back.
                return true
            case .title, .notify, .alert:
                // Skipped (muted) events behave as if they didn't exist outside the list.
                return !event.isAllDay && !hiddenKeys.contains(event.key) && !mutedKeys.contains(event.key)
            }
        }
    }
}
