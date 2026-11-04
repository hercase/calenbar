import Foundation

/// Whole minutes between now and a moment, read the way a wall clock reads them. Every countdown
/// ("in 3m", "3m left") and every "started 3m ago" goes through here, so the menu bar, the panel and
/// the alerts always agree.
public enum RelativeTime {
    /// The minute tick can land a hair before the boundary; within this, it counts as already there.
    static let grace: TimeInterval = 0.5

    /// Minutes still to go, counting the one in progress: 2:58 → 3:00 is 2, and so is 2:58:30.
    /// Never 0 while the moment is ahead, so a countdown doesn't read "in 0m".
    public static func minutesUntil(_ date: Date, now: Date) -> Int {
        let seconds = date.timeIntervalSince(now) - grace
        return max(1, Int((seconds / 60).rounded(.up)))
    }

    /// Minutes already gone, only whole ones: 3:00 → 3:03 is 3, and so is 3:03:59.
    public static func minutesSince(_ date: Date, now: Date) -> Int {
        let seconds = now.timeIntervalSince(date) + grace
        return max(0, Int((seconds / 60).rounded(.down)))
    }

    /// `in 3m` without the words: `3m`, `1h 4m`.
    public static func until(_ date: Date, now: Date) -> String {
        TitleFormatter.compactMinutes(minutesUntil(date, now: now))
    }

    /// `3m ago` without the words: `3m`, `1h 4m`.
    public static func since(_ date: Date, now: Date) -> String {
        TitleFormatter.compactMinutes(minutesSince(date, now: now))
    }
}
