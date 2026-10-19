import Foundation

/// When the menu bar moves on from the ongoing event to the next one.
public enum TitleRule: String, CaseIterable, Codable, Sendable {
    /// Keep the ongoing event until the next one is about to start (default).
    case switchBeforeNextStarts
    /// Keep the ongoing event until it is about to end.
    case switchBeforeCurrentEnds
}

/// How far ahead the menu bar looks for the next event. Beyond it the bar shows only the date.
public enum TitleHorizon: String, CaseIterable, Codable, Sendable {
    case oneHour, twoHours, fourHours, eightHours
    /// The rest of the current day (default).
    case today
    case throughTomorrow, twoDays, sevenDays

    /// Whether an event starting at `start` is within the horizon. Hour windows include their last
    /// instant ("in 4 hours" with a 4-hour horizon shows); day windows stop before the next midnight.
    public func includes(start: Date, from now: Date, calendar: Calendar) -> Bool {
        includes(start: start, limit: limit(from: now, calendar: calendar))
    }

    /// Same test with the limit computed once, for filtering many events.
    public func includes(start: Date, limit: Date) -> Bool {
        switch self {
        case .oneHour, .twoHours, .fourHours, .eightHours: return start <= limit
        case .today, .throughTomorrow, .twoDays, .sevenDays: return start < limit
        }
    }

    /// The far edge of the window.
    public func limit(from now: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        func days(_ count: Int) -> Date { calendar.date(byAdding: .day, value: count, to: startOfToday) ?? now }
        switch self {
        case .oneHour: return now.addingTimeInterval(3_600)
        case .twoHours: return now.addingTimeInterval(2 * 3_600)
        case .fourHours: return now.addingTimeInterval(4 * 3_600)
        case .eightHours: return now.addingTimeInterval(8 * 3_600)
        case .today: return days(1)
        case .throughTomorrow: return days(2)
        case .twoDays: return days(3)
        case .sevenDays: return days(8)
        }
    }
}

/// Picks the single event shown in the menu bar: timed events that are ongoing or start within the
/// horizon. Callers are expected to run `EventFilter` with `.title` first.
public struct TitleSelector: Sendable {
    public static let switchWindow: TimeInterval = 5 * 60

    public let rule: TitleRule
    public let horizon: TitleHorizon
    public let calendar: Calendar

    public init(rule: TitleRule, horizon: TitleHorizon = .today, calendar: Calendar = .current) {
        self.rule = rule
        self.horizon = horizon
        self.calendar = calendar
    }

    public func select(from events: [CalendarEvent], now: Date) -> CalendarEvent? {
        let ongoing =
            events
            .filter { $0.isOngoing(at: now) }
            .max { Self.ranksBefore($1, $0, earliestFirst: false) }
        let limit = horizon.limit(from: now, calendar: calendar)
        let upcoming =
            events
            .filter { $0.start > now && horizon.includes(start: $0.start, limit: limit) }
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
