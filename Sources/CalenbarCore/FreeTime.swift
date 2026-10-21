import Foundation

/// Free stretches in one day's agenda. The list stays compact: a stretch is a label, never empty space
/// proportional to its length.
///
/// Shown before today's first meeting and between meetings. Nothing after the last one — the day has no
/// real end, so "free until tonight" isn't a fact. A later day doesn't grow a morning out of midnight.
/// All-day events don't count as edges.
public enum FreeTime {
    /// Shorter than this is a transition between meetings, not time you can use.
    public static let minimum: TimeInterval = 15 * 60
    /// A new meeting drafted from a gap. A shorter gap uses the whole gap.
    public static let meetingLength: TimeInterval = 30 * 60
    /// How far the meeting start moves inside a longer gap. Moves land on the clock's :00 and :30.
    public static let meetingStep: TimeInterval = 30 * 60
    /// A block that starts at an odd minute ends on the nearest quarter hour, the way invites are written.
    public static let endStep: TimeInterval = 15 * 60
    /// Lunch never fills more than this unless a shorter length is chosen. A longer gap is not a longer lunch.
    public static let lunchLength: TimeInterval = 60 * 60
    private static let lunchMinimum: TimeInterval = 30 * 60

    public enum Label: Equatable, Sendable {
        /// The stretch is open now, or it's the morning before the first meeting: "Free until 9:30".
        case until(Date)
        /// Both edges are meetings and the stretch is still entirely ahead: "30m free".
        case duration(TimeInterval)
    }

    public struct Slot: Equatable, Sendable, Identifiable {
        public let id: String
        /// When the bookable range starts. Inside an open stretch this is "now", not the meeting that already ended.
        public let bookableStart: Date
        public let end: Date
        public let label: FreeTime.Label
        /// False for the morning of a future day: the label is real, but the range would start at midnight.
        public let canBook: Bool

        /// An hour or more is drawn a step stronger, so a long hole doesn't look like a short buffer.
        public var isLong: Bool {
            switch label {
            case .until: end.timeIntervalSince(bookableStart) >= 3_600
            case .duration(let seconds): seconds >= 3_600
            }
        }
    }

    /// What a hover on a bookable gap can create. Lunch is absent when the gap misses the middle of the day.
    public struct Offer: Equatable, Sendable {
        public let focus: DateInterval
        public let lunch: DateInterval?
        public let meeting: DateInterval
    }

    public enum Item: Equatable, Sendable, Identifiable {
        case event(CalendarEvent)
        case overlap(id: String, events: [CalendarEvent])
        case free(Slot)

        public var id: String {
            switch self {
            case .event(let event): event.id
            case .overlap(let id, _): id
            case .free(let slot): slot.id
            }
        }
    }

    /// Timed events that share any minute stay in one group; all-day events stay on their own.
    public static func agenda(
        events: [CalendarEvent],
        on day: Date,
        now: Date,
        calendar: Calendar = .current,
        includeFree: Bool = true
    ) -> [Item] {
        var items: [Item] = []
        var previousEnd: Date?
        var didPlaceLeading = false
        for group in overlapGroups(events) {
            let isTimed = group.contains { !$0.isAllDay }
            if isTimed {
                let start = group.map(\.start).min() ?? now
                let end = group.map(\.end).max() ?? start
                if !didPlaceLeading {
                    didPlaceLeading = true
                    if includeFree, let slot = leadingSlot(before: start, on: day, now: now, calendar: calendar) {
                        items.append(.free(slot))
                    }
                } else if includeFree, let previousEnd {
                    if let slot = between(previousEnd, and: start, now: now, calendar: calendar) {
                        items.append(.free(slot))
                    }
                }
                previousEnd = end
            }
            if group.count > 1 {
                items.append(.overlap(id: group.map(\.id).joined(separator: "+"), events: group))
            } else if let event = group.first {
                items.append(.event(event))
            }
        }
        return items
    }

    /// Focus fills the gap. Lunch only when the gap overlaps 11:30–15:00 for at least 30 minutes,
    /// and it stops at `lunchLength` (30 or 60 minutes). A meeting is the next 30 minutes, or the whole gap when it's shorter.
    public static func offer(
        for slot: Slot, calendar: Calendar = .current, lunchLength: TimeInterval = lunchLength
    ) -> Offer? {
        guard slot.canBook else { return nil }
        let span = slot.end.timeIntervalSince(slot.bookableStart)
        guard span >= minimum else { return nil }
        let focus = DateInterval(start: slot.bookableStart, end: slot.end)
        let meeting = DateInterval(start: slot.bookableStart, duration: min(meetingLength, span))
        return Offer(focus: focus, lunch: lunch(in: focus, length: lunchLength, calendar: calendar), meeting: meeting)
    }

    /// How long the shared block is. `.untilEnd` stays pinned to the next event when the start moves.
    public enum BlockLength: Equatable, Hashable, Sendable {
        case fixed(TimeInterval)
        case untilEnd
    }

    /// The one interval Focus, Lunch and Meeting all use. The start moves by `meetingStep`; the length
    /// is chosen separately and never runs past the next event.
    public struct Placement: Equatable, Sendable {
        public let interval: DateInterval
        public let length: BlockLength
        public let canMoveEarlier: Bool
        public let canMoveLater: Bool
        /// Lengths that still fit from this start. `.untilEnd` stands in for whatever is left when that
        /// isn't already 30 minutes, an hour, or two hours.
        public let choices: [BlockLength]
    }

    /// 30 minutes, an hour, two hours. Anything else is "the rest of the gap".
    public static let lengthOptions: [TimeInterval] = [meetingLength, lunchLength, 2 * 60 * 60]

    /// A block inside the gap. With no stored choice it is `length` (or 30 minutes) from the start.
    /// The start can be "now" (3:46); the end is still a time people write in invites (4:15, not 4:16).
    public static func placement(
        in slot: Slot, preferredStart: Date? = nil, length: BlockLength? = nil, calendar: Calendar = .current
    ) -> Placement {
        let span = slot.end.timeIntervalSince(slot.bookableStart)
        let requested = length ?? .fixed(min(meetingLength, span))
        let interval = interval(in: slot, preferredStart: preferredStart, length: requested, calendar: calendar)
        let resolved = resolvedLength(requested, in: slot, from: interval.start)
        return Placement(
            interval: interval,
            length: resolved,
            canMoveEarlier: shiftedStart(
                in: slot, from: interval.start, length: resolved, forward: false, calendar: calendar) != interval.start,
            canMoveLater: shiftedStart(
                in: slot, from: interval.start, length: resolved, forward: true, calendar: calendar) != interval.start,
            choices: choices(in: slot, from: interval.start, calendar: calendar)
        )
    }

    /// The next :00 or :30 either way. Earlier never passes the gap's start, so from 4:00 it returns to 3:46.
    /// A fixed length that would no longer fit stays where it is.
    public static func shiftedStart(
        in slot: Slot, from start: Date, length: BlockLength, forward: Bool, calendar: Calendar = .current
    ) -> Date {
        let mark = floorToMark(start, step: meetingStep, calendar: calendar)
        let candidate: Date
        if forward {
            candidate = mark.addingTimeInterval(meetingStep)
        } else {
            let previous = mark < start - 0.5 ? mark : mark.addingTimeInterval(-meetingStep)
            candidate = max(previous, slot.bookableStart)
        }
        guard forward || candidate < start - 0.5 else { return start }
        let placed = interval(in: slot, preferredStart: candidate, length: length, calendar: calendar)
        if forward, placed.start + 0.5 < start { return start }
        if !forward, placed.start > start + 0.5 { return start }
        if placed.duration + 0.5 < minimum { return start }
        if case .fixed(let value) = length, placed.start.addingTimeInterval(value) > slot.end + 0.5 { return start }
        return placed.start
    }

    private static func interval(
        in slot: Slot, preferredStart: Date?, length: BlockLength, calendar: Calendar
    ) -> DateInterval {
        let raw = preferredStart ?? slot.bookableStart
        switch length {
        case .untilEnd:
            let start = min(max(raw, slot.bookableStart), slot.end)
            return DateInterval(start: start, end: max(start, slot.end))
        case .fixed(let value):
            let latest = max(slot.end.addingTimeInterval(-max(value, 0)), slot.bookableStart)
            let start = min(max(raw, slot.bookableStart), latest)
            return DateInterval(start: start, end: blockEnd(from: start, length: value, in: slot, calendar: calendar))
        }
    }

    /// The next meeting is a real edge and wins as is. Otherwise the end moves to the nearest quarter hour,
    /// never leaving less than `minimum`.
    private static func blockEnd(from start: Date, length: TimeInterval, in slot: Slot, calendar: Calendar) -> Date {
        let exact = start.addingTimeInterval(max(length, 0))
        guard exact < slot.end - 0.5 else { return slot.end }
        var rounded = floorToMark(exact.addingTimeInterval(endStep / 2), step: endStep, calendar: calendar)
        if rounded.timeIntervalSince(start) + 0.5 < minimum { rounded = rounded.addingTimeInterval(endStep) }
        return min(max(rounded, start), slot.end)
    }

    /// A requested hour inside a 20-minute gap is just the gap.
    private static func resolvedLength(_ requested: BlockLength, in slot: Slot, from start: Date) -> BlockLength {
        switch requested {
        case .untilEnd: .untilEnd
        case .fixed(let value): start.addingTimeInterval(value) <= slot.end + 1 ? .fixed(value) : .untilEnd
        }
    }

    /// A length is offered only when it fits. "The rest of the gap" is dropped when one of them already ends there,
    /// so 3:58 in a gap until 4:30 doesn't offer both "30m" and "32m" for the same 3:58–4:30.
    private static func choices(in slot: Slot, from start: Date, calendar: Calendar) -> [BlockLength] {
        let room = slot.end.timeIntervalSince(start)
        guard room >= minimum else { return [] }
        let fitting = lengthOptions.filter { $0 >= minimum && $0 <= room + 0.5 }
        let reachesEnd = fitting.contains { option in
            abs(blockEnd(from: start, length: option, in: slot, calendar: calendar).timeIntervalSince(slot.end)) < 1
        }
        return fitting.map { .fixed($0) } + (reachesEnd ? [] : [.untilEnd])
    }

    /// The last :00/:15/:30/:45 the local clock showed. Counted inside the hour, so zones half or three
    /// quarters of an hour off UTC (India, Nepal) still land where their clock does.
    private static func floorToMark(_ date: Date, step: TimeInterval, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.minute, .second, .nanosecond], from: date)
        let intoHour =
            TimeInterval((parts.minute ?? 0) * 60 + (parts.second ?? 0)) + TimeInterval(parts.nanosecond ?? 0) / 1e9
        return date.addingTimeInterval(-intoHour.truncatingRemainder(dividingBy: step))
    }

    // MARK: - Gaps

    /// Before the first meeting, and only on today. A later day has no real start: midnight isn't when
    /// the morning begins, and the first event already says when it does.
    private static func leadingSlot(before end: Date, on day: Date, now: Date, calendar: Calendar) -> Slot? {
        guard calendar.isDate(day, inSameDayAs: now) else { return nil }
        let bookable = ceilToMinute(now, calendar: calendar)
        guard bookable < end, end.timeIntervalSince(bookable) >= minimum else { return nil }
        return Slot(
            id: slotID(calendar.startOfDay(for: day), end), bookableStart: bookable, end: end, label: .until(end),
            canBook: true)
    }

    /// Between two timed blocks. A gap you're already standing in reads as "free until", and one
    /// with less than `minimum` left is hidden.
    private static func between(_ start: Date, and end: Date, now: Date, calendar: Calendar) -> Slot? {
        guard end.timeIntervalSince(start) >= minimum, end > now else { return nil }
        let bookable = max(start, ceilToMinute(now, calendar: calendar))
        guard end.timeIntervalSince(bookable) >= minimum else { return nil }
        let label: Label = now > start ? .until(end) : .duration(end.timeIntervalSince(start))
        return Slot(id: slotID(start, end), bookableStart: bookable, end: end, label: label, canBook: true)
    }

    /// 11:30–15:00 on the gap's day, capped at `length`, and only when at least 30 minutes of it is free.
    private static func lunch(in focus: DateInterval, length: TimeInterval, calendar: Calendar) -> DateInterval? {
        guard let windowStart = calendar.date(bySettingHour: 11, minute: 30, second: 0, of: focus.start),
            let windowEnd = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: focus.start)
        else { return nil }
        let start = max(focus.start, windowStart)
        let end = min(focus.end, windowEnd)
        let available = end.timeIntervalSince(start)
        guard available >= lunchMinimum else { return nil }
        return DateInterval(start: start, duration: min(length, available))
    }

    private static func slotID(_ start: Date, _ end: Date) -> String {
        "free|\(Int(start.timeIntervalSince1970))|\(Int(end.timeIntervalSince1970))"
    }

    /// Whole minutes, so a block never starts a few seconds in the past.
    private static func ceilToMinute(_ date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard (parts.second ?? 0) > 0 else { return date }
        var truncated = parts
        truncated.second = 0
        guard let startOfMinute = calendar.date(from: truncated),
            let next = calendar.date(byAdding: .minute, value: 1, to: startOfMinute)
        else { return date }
        return next
    }

    /// Consecutive timed events that share any minute form a group. Same rule the list used before
    /// free time existed, so a clash and a gap can't disagree about where a meeting ends.
    private static func overlapGroups(_ events: [CalendarEvent]) -> [[CalendarEvent]] {
        var groups: [[CalendarEvent]] = []
        var groupEnd = Date.distantPast
        for event in events {
            if !event.isAllDay, let last = groups.last, !last.isEmpty, !last[0].isAllDay, event.start < groupEnd {
                groups[groups.count - 1].append(event)
            } else {
                groups.append([event])
                groupEnd = Date.distantPast
            }
            if !event.isAllDay {
                groupEnd = max(groupEnd, event.end)
            }
        }
        return groups
    }
}
