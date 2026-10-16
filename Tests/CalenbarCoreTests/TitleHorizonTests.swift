import Foundation
import Testing

@testable import CalenbarCore

struct TitleHorizonTests {
    let now = Fixture.at(9, 0)
    let soon = Fixture.event("Soon", Fixture.at(10, 30), Fixture.at(11, 0))
    let afternoon = Fixture.event("Afternoon", Fixture.at(17, 0), Fixture.at(18, 0))
    let tomorrow = Fixture.event("Tomorrow", Fixture.at(9, 0, day: 16), Fixture.at(10, 0, day: 16))
    let nextWeek = Fixture.event("Next week", Fixture.at(9, 0, day: 21), Fixture.at(10, 0, day: 21))

    func selector(_ horizon: TitleHorizon) -> TitleSelector {
        TitleSelector(rule: .switchBeforeNextStarts, horizon: horizon, calendar: Fixture.calendar)
    }

    @Test func hourWindowsOnlySeeWhatStartsInside() {
        let events = [soon, afternoon, tomorrow]
        #expect(selector(.oneHour).select(from: events, now: now) == nil)
        #expect(selector(.twoHours).select(from: events, now: now)?.title == "Soon")
        #expect(selector(.eightHours).select(from: [afternoon, tomorrow], now: now)?.title == "Afternoon")
        #expect(selector(.fourHours).select(from: [afternoon, tomorrow], now: now) == nil)
    }

    @Test func todayStopsAtMidnight() {
        #expect(selector(.today).select(from: [afternoon, tomorrow], now: now)?.title == "Afternoon")
        #expect(selector(.today).select(from: [tomorrow], now: now) == nil)
    }

    @Test func dayHorizonsReachIntoFollowingDays() {
        #expect(selector(.throughTomorrow).select(from: [tomorrow, nextWeek], now: now)?.title == "Tomorrow")
        #expect(selector(.throughTomorrow).select(from: [nextWeek], now: now) == nil)
        #expect(selector(.sevenDays).select(from: [nextWeek], now: now)?.title == "Next week")
    }

    @Test func ongoingEventShowsRegardlessOfHorizon() {
        let ongoing = Fixture.event("Ongoing", Fixture.at(8, 30), Fixture.at(9, 30))
        #expect(selector(.oneHour).select(from: [ongoing, afternoon], now: now)?.title == "Ongoing")
    }

    @Test func hourWindowsIncludeTheirLastInstantButDaysStopBeforeMidnight() {
        let calendar = Fixture.calendar
        #expect(TitleHorizon.eightHours.includes(start: Fixture.at(17, 0), from: now, calendar: calendar))
        #expect(!TitleHorizon.eightHours.includes(start: Fixture.at(17, 0, 1), from: now, calendar: calendar))
        #expect(!TitleHorizon.today.includes(start: Fixture.at(0, 0, day: 16), from: now, calendar: calendar))
    }

    @Test func limitsAreComputedFromTheStartOfToday() {
        let calendar = Fixture.calendar
        #expect(TitleHorizon.today.limit(from: now, calendar: calendar) == Fixture.at(0, 0, day: 16))
        #expect(TitleHorizon.throughTomorrow.limit(from: now, calendar: calendar) == Fixture.at(0, 0, day: 17))
        #expect(TitleHorizon.twoHours.limit(from: now, calendar: calendar) == Fixture.at(11, 0))
    }
}
