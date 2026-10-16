import Foundation
import Testing

@testable import CalenbarCore

struct AlertTimingTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var event: CalendarEvent { Fixture.event("Sync", start, start.addingTimeInterval(30 * 60)) }

    @Test func firesFromLeadUntilShortlyAfterStart() {
        #expect(!AlertTiming.isDue(event: event, now: start.addingTimeInterval(-121), lead: 120, snoozedUntil: nil))
        #expect(AlertTiming.isDue(event: event, now: start.addingTimeInterval(-120), lead: 120, snoozedUntil: nil))
        #expect(AlertTiming.isDue(event: event, now: start.addingTimeInterval(4 * 60), lead: 0, snoozedUntil: nil))
        #expect(!AlertTiming.isDue(event: event, now: start.addingTimeInterval(5 * 60), lead: 0, snoozedUntil: nil))
    }

    @Test func snoozeWaitsThenComesBackEvenAfterTheWindow() {
        let until = start.addingTimeInterval(10 * 60)
        #expect(!AlertTiming.isDue(event: event, now: start.addingTimeInterval(9 * 60), lead: 0, snoozedUntil: until))
        #expect(AlertTiming.isDue(event: event, now: until, lead: 0, snoozedUntil: until))
    }

    @Test func snoozePastTheEndNeverFires() {
        let until = start.addingTimeInterval(31 * 60)
        #expect(!AlertTiming.isDue(event: event, now: until, lead: 0, snoozedUntil: until))
    }
}

struct DisplayLocationTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func hidesLocationsThatOnlyRepeatTheMeeting() {
        let url = URL(string: "https://zoom.us/j/123")
        #expect(
            Fixture.event("Sync", start, start.addingTimeInterval(1_800), url: url, location: "https://zoom.us/j/123")
                .displayLocation == nil)
        #expect(
            Fixture.event("Sync", start, start.addingTimeInterval(1_800), url: url, location: "Zoom Meeting").displayLocation
                == nil)
        #expect(Fixture.event("Sync", start, start.addingTimeInterval(1_800), url: url, location: "  ").displayLocation == nil)
    }

    @Test func keepsRealPlaces() {
        let url = URL(string: "https://zoom.us/j/123")
        #expect(
            Fixture.event("Sync", start, start.addingTimeInterval(1_800), url: url, location: "Zoom Room 2").displayLocation
                == "Zoom Room 2")
        #expect(
            Fixture.event("Sync", start, start.addingTimeInterval(1_800), location: " Floor 4 ").displayLocation == "Floor 4")
    }
}
