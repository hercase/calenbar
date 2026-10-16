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
    /// Keys of skipped occurrences (see `CalendarEvent.key`).
    public var mutedKeys: Set<String>

    public init(disabledCalendars: [CalendarPurpose: Set<String>] = [:], mutedKeys: Set<String> = []) {
        self.disabledCalendars = disabledCalendars
        self.mutedKeys = mutedKeys
    }

    public func apply(_ events: [CalendarEvent], for purpose: CalendarPurpose) -> [CalendarEvent] {
        let disabled = disabledCalendars[purpose] ?? []
        return events.filter { event in
            guard !event.isDeclined, !disabled.contains(event.calendarID) else { return false }
            switch purpose {
            case .list:
                // Skipped events stay in the list (dimmed) so they can be brought back.
                return true
            case .title, .notify, .alert:
                // Skipped events behave as if they didn't exist outside the list.
                return !event.isAllDay && !mutedKeys.contains(event.key)
            }
        }
    }
}
