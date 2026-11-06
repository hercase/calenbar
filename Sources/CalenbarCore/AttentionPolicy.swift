import Foundation

/// When the menu bar item flashes red / pings as an event approaches, and yellow for a meeting right
/// behind the current one.
public enum AttentionPolicy {
    /// - Last 30 seconds: flash every other second.
    /// - With `fromFiveMinutes`, once under 5 minutes are left: 5 quick flashes at the end of each minute.
    ///   The menu bar rounds up, so 5m 51s left still reads "in 6m" and stays quiet; the first burst is at 4m 59s.
    public static func isFlashOn(start: Date, now: Date, fromFiveMinutes: Bool) -> Bool {
        guard let (minutes, seconds) = timeLeft(until: start, from: now) else { return false }
        if minutes == 0, seconds <= 30 {
            return seconds.isMultiple(of: 2)
        }
        if fromFiveMinutes, minutes < 5 {
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

    /// While you're still in a meeting, how long before the next one starts the bar warns, once, in yellow.
    public static let followUpLead = 10

    /// One burst of 5 quick flashes as `followUpLead` minutes are about to be left before the meeting
    /// right behind the current one (9m 59s to 9m 51s, like the red bursts).
    public static func isFollowUpFlashOn(start: Date, now: Date) -> Bool {
        guard let (minutes, seconds) = timeLeft(until: start, from: now) else { return false }
        return minutes == followUpLead - 1 && seconds > 50 && !seconds.isMultiple(of: 2)
    }

    /// The yellow burst needs a per-second timer only around it: the minute before and after, so the
    /// status item's once-a-minute refresh always lands inside and starts it in time.
    public static func needsFollowUpTicks(start: Date, now: Date) -> Bool {
        let left = start.timeIntervalSince(now)
        let lead = Double(followUpLead * 60)
        return left > lead - 60 && left <= lead + 60
    }

    /// Whole minutes and seconds until `start`, or nil once it has started.
    private static func timeLeft(until start: Date, from now: Date) -> (minutes: Int, seconds: Int)? {
        let left = Int(start.timeIntervalSince(now).rounded())
        guard left > 0 else { return nil }
        return (left / 60, left % 60)
    }
}
