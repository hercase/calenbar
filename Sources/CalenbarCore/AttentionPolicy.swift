import Foundation

/// When the menu bar item flashes red / pings as an event approaches.
public enum AttentionPolicy {
    /// - Last 30 seconds: flash every other second.
    /// - With `fromFiveMinutes`, within the last 5 minutes: 5 quick flashes at the end of each minute.
    public static func isFlashOn(start: Date, now: Date, fromFiveMinutes: Bool) -> Bool {
        guard let (minutes, seconds) = timeLeft(until: start, from: now) else { return false }
        if minutes == 0, seconds <= 30 {
            return seconds.isMultiple(of: 2)
        }
        if fromFiveMinutes, minutes <= 5 {
            return seconds > 50 && !seconds.isMultiple(of: 2)
        }
        return false
    }

    /// Ping at 5 minutes (when `fromFiveMinutes`) and at 30 seconds before start.
    public static func shouldPing(start: Date, now: Date, fromFiveMinutes: Bool) -> Bool {
        guard let (minutes, seconds) = timeLeft(until: start, from: now) else { return false }
        return (fromFiveMinutes && minutes == 5 && seconds == 0) || (minutes == 0 && seconds == 30)
    }

    /// Flashing needs a per-second timer; only run it in the 6 minutes before start.
    public static func needsSecondTicks(start: Date, now: Date) -> Bool {
        let left = start.timeIntervalSince(now)
        return left > 0 && left <= 6 * 60
    }

    /// Whole minutes and seconds until `start`, or nil once it has started.
    private static func timeLeft(until start: Date, from now: Date) -> (minutes: Int, seconds: Int)? {
        let left = Int(start.timeIntervalSince(now).rounded())
        guard left > 0 else { return nil }
        return (left / 60, left % 60)
    }
}
