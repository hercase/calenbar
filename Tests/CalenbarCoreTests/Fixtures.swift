import Foundation

@testable import CalenbarCore

/// Fixed reference day: 2026-10-15 in UTC, so tests don't depend on the machine's time zone.
enum Fixture {
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    static func at(_ hour: Int, _ minute: Int, _ second: Int = 0, day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
    }

    static func event(
        _ title: String,
        _ start: Date,
        _ end: Date,
        id: String? = nil,
        calendarID: String = "work",
        isAllDay: Bool = false,
        isDeclined: Bool = false,
        hasOtherAttendees: Bool = false,
        url: URL? = nil,
        location: String? = nil,
        notes: String? = nil,
        attendees: [Attendee] = [],
        myStatus: ParticipationStatus = .unknown,
        isRecurring: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: id ?? title,
            externalID: id ?? title,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            calendarID: calendarID,
            calendarTitle: calendarID,
            calendarColorHex: "#3B82F6",
            isDeclined: isDeclined,
            hasOtherAttendees: hasOtherAttendees,
            url: url,
            location: location,
            notes: notes,
            attendees: attendees,
            myStatus: myStatus,
            isRecurring: isRecurring
        )
    }
}
