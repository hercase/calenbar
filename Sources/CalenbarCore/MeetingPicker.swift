import Foundation

/// Which meeting "Join the next meeting" means.
public enum MeetingPicker {
    /// The event in the menu bar when it has a link (it's the one the user is looking at); otherwise
    /// the earliest event with a link that hasn't ended yet.
    public static func next(titleEvent: CalendarEvent?, candidates: [CalendarEvent], now: Date) -> CalendarEvent? {
        if let titleEvent, titleEvent.meetingLink != nil {
            return titleEvent
        }
        return
            candidates
            .filter { $0.meetingLink != nil && $0.end > now && !$0.isAllDay }
            .min { $0.start < $1.start }
    }
}
