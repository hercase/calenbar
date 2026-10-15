import Foundation

/// When the menu bar moves on from the ongoing event to the next one.
public enum TitleRule: String, CaseIterable, Codable, Sendable {
    /// Keep the ongoing event until the next one is about to start (default).
    case switchBeforeNextStarts
    /// Keep the ongoing event until it is about to end.
    case switchBeforeCurrentEnds
}

/// Picks the single event shown in the menu bar. Only considers today's timed events;
/// callers are expected to run `EventFilter` with `.title` first.
public struct TitleSelector: Sendable {
    public static let switchWindow: TimeInterval = 5 * 60

    public let rule: TitleRule
    public let calendar: Calendar

    public init(rule: TitleRule, calendar: Calendar = .current) {
        self.rule = rule
        self.calendar = calendar
    }

    public func select(from events: [CalendarEvent], now: Date) -> CalendarEvent? {
        let today = events.filter { calendar.isDate($0.start, inSameDayAs: now) }

        let ongoing =
            today
            .filter { $0.isOngoing(at: now) }
            .max { Self.ranksBefore($1, $0, earliestFirst: false) }
        let upcoming =
            today
            .filter { $0.start > now }
            .min { Self.ranksBefore($0, $1, earliestFirst: true) }

        guard let ongoing else { return upcoming }

        switch rule {
        case .switchBeforeNextStarts:
            if let upcoming, upcoming.start.timeIntervalSince(now) <= Self.switchWindow {
                return upcoming
            }
            return ongoing
        case .switchBeforeCurrentEnds:
            if ongoing.end.timeIntervalSince(now) <= Self.switchWindow {
                return upcoming
            }
            return ongoing
        }
    }

    /// Orders by start time; on a tie, events with other attendees win (real meetings over focus blocks).
    private static func ranksBefore(_ lhs: CalendarEvent, _ rhs: CalendarEvent, earliestFirst: Bool) -> Bool {
        if lhs.start != rhs.start {
            return earliestFirst ? lhs.start < rhs.start : lhs.start > rhs.start
        }
        return lhs.hasOtherAttendees && !rhs.hasOtherAttendees
    }
}
