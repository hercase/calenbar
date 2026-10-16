import Foundation

/// When the full-screen alert for an event is due.
public enum AlertTiming {
    /// Minutes after the start during which a never-shown alert may still appear (the Mac was asleep,
    /// the app was just launched).
    public static let window: TimeInterval = 5 * 60

    /// A snoozed alert comes back when the snooze ends, as long as the event is still running.
    /// Otherwise it fires from `lead` before the start until shortly after it.
    public static func isDue(event: CalendarEvent, now: Date, lead: TimeInterval, snoozedUntil: Date?) -> Bool {
        if let snoozedUntil {
            return now >= snoozedUntil && now < event.end
        }
        let fireAt = event.start.addingTimeInterval(-lead)
        return now >= fireAt && now < event.start.addingTimeInterval(window)
    }

    /// Snooze lengths offered on the alert, in minutes.
    public static let snoozeMinutes = [1, 5, 10]
}
