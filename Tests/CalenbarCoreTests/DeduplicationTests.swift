import Foundation
import Testing

@testable import CalenbarCore

struct DeduplicationTests {
    let zoom = URL(string: "https://zoom.us/j/1")

    @Test func sameEventInSeveralCalendarsAppearsOnce() {
        let events = [
            Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0), id: "a", calendarID: "work"),
            Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0), id: "b", calendarID: "shared"),
            Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0), id: "c", calendarID: "team"),
        ]
        #expect(CalendarEvent.deduplicated(events).count == 1)
    }

    @Test func prefersTheCopyWithAMeetingLink() {
        let events = [
            Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0), id: "plain"),
            Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0), id: "linked", url: zoom),
        ]
        #expect(CalendarEvent.deduplicated(events).map(\.id) == ["linked"])
    }

    @Test func keepsDistinctEventsAndOrder() {
        let events = [
            Fixture.event("Standup", Fixture.at(10, 0), Fixture.at(10, 30)),
            Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0)),
            Fixture.event("Class", Fixture.at(16, 0), Fixture.at(17, 0), id: "later"),
        ]
        #expect(CalendarEvent.deduplicated(events).map(\.id) == ["Standup", "Class", "later"])
    }

    @Test func titleComparisonIgnoresCaseAndSpaces() {
        let events = [
            Fixture.event("Town Hall ", Fixture.at(16, 0), Fixture.at(17, 0), id: "a"),
            Fixture.event("town hall", Fixture.at(16, 0), Fixture.at(17, 0), id: "b"),
        ]
        #expect(CalendarEvent.deduplicated(events).count == 1)
    }
}
