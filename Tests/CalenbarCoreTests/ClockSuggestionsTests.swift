import Foundation
import Testing

@testable import CalenbarCore

struct ClockSuggestionsTests {
    private let now = Fixture.at(12, 0)
    private let buenosAires = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    private func event(
        _ id: String, zone: String? = nil, title: String = "Sync", day: Int = 16, allDay: Bool = false
    ) -> CalendarEvent {
        let start = Fixture.at(15, 0, day: day)
        return Fixture.event(title, start, Fixture.at(16, 0, day: day), id: id, isAllDay: allDay, timeZoneID: zone)
    }

    private func suggest(
        _ events: [CalendarEvent], existing: Set<String> = [], dismissed: [String: ClockDismissal] = [:]
    ) -> [ClockSuggestion] {
        ClockSuggestions.suggest(events: events, now: now, system: buenosAires, existing: existing, dismissed: dismissed)
    }

    @Test func foreignZonesAreRankedByEventCount() {
        let events =
            [event("a", zone: "America/Chicago"), event("b", zone: "America/Chicago")]
            + (0..<3).map { event("l\($0)", zone: "Europe/London") }
        #expect(suggest(events).map(\.timeZoneID) == ["Europe/London", "America/Chicago"])
    }

    @Test func ownZoneAndExistingClocksAreNeverSuggested() {
        let events =
            (0..<3).map { event("h\($0)", zone: "America/Argentina/Buenos_Aires") }
            + (0..<3).map { event("n\($0)", zone: "America/New_York") }
        #expect(suggest(events).isEmpty == false)
        #expect(suggest(events, existing: ["America/New_York"]).isEmpty)
    }

    @Test func aSingleEventIsNotEnough() {
        #expect(suggest([event("a", zone: "Europe/London")]).isEmpty)
    }

    @Test func aRecurringSeriesCountsOnce() {
        let series = (16...20).map { event("daily", zone: "Europe/London", day: $0) }
        #expect(suggest(series).isEmpty)
    }

    @Test func allDayAndZonelessEventsAreIgnored() {
        let events = [
            event("a", zone: "Europe/London", allDay: true), event("b", zone: "Europe/London", allDay: true), event("c"),
        ]
        #expect(suggest(events).isEmpty)
    }

    @Test func zonesSharingTheSameClockAreNotDuplicated() {
        let events = ["a", "b"].map { event($0, zone: "America/Toronto") }
        #expect(suggest(events, existing: ["America/New_York"]).isEmpty)
    }

    @Test func aTimeFollowedByAZoneNameCounts() {
        let events = [event("a", title: "Planning 11am PT"), event("b", title: "Review 3:30 PM PT")]
        #expect(suggest(events).map(\.timeZoneID) == ["America/Los_Angeles"])
    }

    @Test func textWithoutATimeIsNotAZone() {
        let events = [event("a", title: "PT review"), event("b", title: "Done in part 2 pt")]
        #expect(suggest(events).isEmpty)
    }

    @Test func mentionsReadTheNotesAndLocationToo() {
        let notes = Fixture.event("x", Fixture.at(15, 0), Fixture.at(16, 0), id: "x", notes: "Starts 10:00 CET sharp")
        let location = Fixture.event("y", Fixture.at(15, 0), Fixture.at(16, 0), id: "y", location: "Room 4 (9am CET)")
        #expect(suggest([notes, location]).map(\.timeZoneID) == ["Europe/Berlin"])
    }

    @Test func aFreshDismissalHidesTheZone() {
        let events = ["a", "b"].map { event($0, zone: "Europe/London") }
        let dismissed = ["Europe/London": ClockDismissal(date: now.addingTimeInterval(-86_400), eventCount: 2)]
        #expect(suggest(events, dismissed: dismissed).isEmpty)
    }

    @Test func aDismissalExpiresAfterNinetyDays() {
        let events = ["a", "b"].map { event($0, zone: "Europe/London") }
        let dismissed = ["Europe/London": ClockDismissal(date: now.addingTimeInterval(-91 * 86_400), eventCount: 2)]
        #expect(suggest(events, dismissed: dismissed).count == 1)
    }

    @Test func aDismissedZoneReturnsWhenItGetsMuchBusier() {
        let events = (0..<6).map { event("e\($0)", zone: "Europe/London") }
        let dismissed = ["Europe/London": ClockDismissal(date: now.addingTimeInterval(-86_400), eventCount: 2)]
        #expect(suggest(events, dismissed: dismissed).count == 1)
    }

    @Test func atMostThreeAreReturned() {
        let zones = ["Europe/London", "Europe/Berlin", "America/Chicago", "Asia/Tokyo"]
        let events = zones.flatMap { zone in (0..<2).map { event("\(zone)\($0)", zone: zone) } }
        #expect(suggest(events).count == 3)
    }

    @Test func nothingInNothingOut() {
        #expect(suggest([]).isEmpty)
    }

    @Test func cityNameIsReadableFromTheIdentifier() {
        let suggestion = ClockSuggestion(timeZoneID: "America/Los_Angeles", eventCount: 3, lastEvent: now)
        #expect(suggestion.cityName == "Los Angeles")
    }
}
