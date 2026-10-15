import Foundation
import Testing

@testable import CalenbarCore

struct TitleSelectorNextStartsRuleTests {
    let selector = TitleSelector(rule: .switchBeforeNextStarts, calendar: Fixture.calendar)

    @Test func noEventsSelectsNothing() {
        #expect(selector.select(from: [], now: Fixture.at(10, 0)) == nil)
    }

    @Test func onlyPastEventsSelectsNothing() {
        let past = Fixture.event("Past", Fixture.at(8, 0), Fixture.at(9, 0))
        #expect(selector.select(from: [past], now: Fixture.at(10, 0)) == nil)
    }

    @Test func picksEarliestUpcoming() {
        let later = Fixture.event("A", Fixture.at(15, 0), Fixture.at(16, 0))
        let earlier = Fixture.event("B", Fixture.at(11, 0), Fixture.at(12, 0))
        #expect(selector.select(from: [later, earlier], now: Fixture.at(10, 0))?.title == "B")
    }

    @Test func ongoingWinsWhenNextIsMoreThanFiveMinutesAway() {
        let ongoing = Fixture.event("Standup", Fixture.at(13, 30), Fixture.at(14, 0))
        let next = Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0))
        #expect(selector.select(from: [ongoing, next], now: Fixture.at(13, 35))?.title == "Standup")
    }

    @Test func switchesToNextWhenItStartsWithinFiveMinutes() {
        let ongoing = Fixture.event("Standup", Fixture.at(13, 30), Fixture.at(15, 0))
        let next = Fixture.event("Class", Fixture.at(14, 0), Fixture.at(15, 0))
        #expect(selector.select(from: [ongoing, next], now: Fixture.at(13, 55))?.title == "Class")
    }

    @Test func keepsOngoingUntilItEndsWhenNothingFollows() {
        let ongoing = Fixture.event("Standup", Fixture.at(13, 30), Fixture.at(14, 0))
        #expect(selector.select(from: [ongoing], now: Fixture.at(13, 58))?.title == "Standup")
    }

    @Test func overlappingOngoingPrefersLatestStarted() {
        let long = Fixture.event("Long", Fixture.at(9, 0), Fixture.at(17, 0))
        let short = Fixture.event("Short", Fixture.at(13, 0), Fixture.at(14, 0))
        #expect(selector.select(from: [long, short], now: Fixture.at(13, 10))?.title == "Short")
    }

    @Test func ignoresTomorrowsEvents() {
        let tomorrow = Fixture.event("Tomorrow", Fixture.at(9, 0, day: 16), Fixture.at(10, 0, day: 16))
        #expect(selector.select(from: [tomorrow], now: Fixture.at(20, 0)) == nil)
    }

    @Test func tieOnStartPrefersEventWithOtherAttendees() {
        let solo = Fixture.event("Focus", Fixture.at(11, 0), Fixture.at(12, 0))
        let meeting = Fixture.event("Sync", Fixture.at(11, 0), Fixture.at(12, 0), hasOtherAttendees: true)
        #expect(selector.select(from: [solo, meeting], now: Fixture.at(10, 0))?.title == "Sync")
    }
}

struct TitleSelectorEndRuleTests {
    let selector = TitleSelector(rule: .switchBeforeCurrentEnds, calendar: Fixture.calendar)

    @Test func ongoingWinsBeforeLastFiveMinutes() {
        let ongoing = Fixture.event("Standup", Fixture.at(13, 30), Fixture.at(14, 0))
        let next = Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0))
        #expect(selector.select(from: [ongoing, next], now: Fixture.at(13, 50))?.title == "Standup")
    }

    @Test func switchesToNextInLastFiveMinutes() {
        let ongoing = Fixture.event("Standup", Fixture.at(13, 30), Fixture.at(14, 0))
        let next = Fixture.event("Class", Fixture.at(15, 0), Fixture.at(16, 0))
        #expect(selector.select(from: [ongoing, next], now: Fixture.at(13, 56))?.title == "Class")
    }

    @Test func lastFiveMinutesWithNothingNextSelectsNothing() {
        let ongoing = Fixture.event("Standup", Fixture.at(13, 30), Fixture.at(14, 0))
        #expect(selector.select(from: [ongoing], now: Fixture.at(13, 56)) == nil)
    }

    @Test func ignoresNextStartingSoonWhileCurrentHasTimeLeft() {
        let ongoing = Fixture.event("Workshop", Fixture.at(13, 0), Fixture.at(15, 0))
        let next = Fixture.event("Class", Fixture.at(14, 0), Fixture.at(15, 0))
        #expect(selector.select(from: [ongoing, next], now: Fixture.at(13, 57))?.title == "Workshop")
    }
}
