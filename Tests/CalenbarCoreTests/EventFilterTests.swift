import Foundation
import Testing

@testable import CalenbarCore

struct EventFilterTests {
    let normal = Fixture.event("Normal", Fixture.at(10, 0), Fixture.at(11, 0))
    let allDay = Fixture.event("Holiday", Fixture.at(0, 0), Fixture.at(0, 0, day: 16), isAllDay: true)
    let declined = Fixture.event("Declined", Fixture.at(12, 0), Fixture.at(13, 0), isDeclined: true)
    let personal = Fixture.event("Gym", Fixture.at(18, 0), Fixture.at(19, 0), calendarID: "personal")

    func filter(
        disabled: [CalendarPurpose: Set<String>] = [:], muted: Set<String> = [], quiet: Set<String> = []
    ) -> EventFilter {
        EventFilter(disabledCalendars: disabled, mutedKeys: muted, quietKeys: quiet)
    }

    @Test func titleExcludesAllDayDeclinedAndSkipped() {
        let sut = filter(muted: [personal.key])
        let result = sut.apply([normal, allDay, declined, personal], for: .title)
        #expect(result.map(\.title) == ["Normal"])
    }

    @Test func listKeepsAllDayAndSkippedButDropsDeclined() {
        let sut = filter(muted: [personal.key])
        let result = sut.apply([normal, allDay, declined, personal], for: .list)
        #expect(result.map(\.title) == ["Normal", "Holiday", "Gym"])
    }

    @Test func calendarOutOfTheListIsOutEverywhere() {
        let sut = filter(disabled: [.list: ["personal"]])
        for purpose in CalendarPurpose.allCases {
            #expect(sut.apply([normal, personal], for: purpose).map(\.title) == ["Normal"])
        }
        // Off for notifications only: still listed and in the menu bar.
        let notifyOnly = filter(disabled: [.notify: ["personal"]])
        #expect(notifyOnly.apply([personal], for: .notify).isEmpty)
        #expect(notifyOnly.apply([personal], for: .list).count == 1)
    }

    @Test func skippedEventIsGoneEverywhereButTheList() {
        let sut = filter(muted: [normal.key])
        #expect(sut.apply([normal], for: .title).isEmpty)
        #expect(sut.apply([normal], for: .notify).isEmpty)
        #expect(sut.apply([normal], for: .alert).isEmpty)
        #expect(sut.apply([normal], for: .list).map(\.title) == ["Normal"])
    }

    @Test func disabledCalendarIsPerPurpose() {
        let sut = filter(disabled: [.title: ["personal"]])
        #expect(sut.apply([personal], for: .title).isEmpty)
        #expect(sut.apply([personal], for: .list).map(\.title) == ["Gym"])
    }

    @Test func quietBlockStaysInTheListAndOutOfTheMenuBar() {
        let sut = filter(quiet: [normal.key])
        #expect(sut.apply([normal], for: .list).map(\.title) == ["Normal"])
        #expect(sut.apply([normal], for: .title).isEmpty)
        #expect(sut.apply([normal], for: .notify).isEmpty)
        #expect(sut.apply([normal], for: .alert).isEmpty)
    }

    @Test func recurringInstancesHaveDistinctKeys() {
        let monday = Fixture.event("Standup", Fixture.at(9, 0), Fixture.at(9, 15), id: "series-1")
        let tuesday = Fixture.event("Standup", Fixture.at(9, 0, day: 16), Fixture.at(9, 15, day: 16), id: "series-1")
        #expect(monday.key != tuesday.key)
    }
}
