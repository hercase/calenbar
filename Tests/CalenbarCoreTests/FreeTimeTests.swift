import Foundation
import Testing

@testable import CalenbarCore

struct FreeTimeTests {
    private let calendar = Fixture.calendar
    private let day = Fixture.at(0, 0)

    private func agenda(_ events: [CalendarEvent], now: Date, on day: Date? = nil, includeFree: Bool = true) -> [FreeTime.Item] {
        FreeTime.agenda(events: events, on: day ?? self.day, now: now, calendar: calendar, includeFree: includeFree)
    }

    private func slots(in items: [FreeTime.Item]) -> [FreeTime.Slot] {
        items.compactMap { if case .free(let slot) = $0 { slot } else { nil } }
    }

    @Test func morningSaysFreeUntilTheFirstMeeting() {
        let now = Fixture.at(8, 0)
        let standup = Fixture.event("Standup", Fixture.at(9, 30), Fixture.at(10, 0))
        let items = agenda([standup], now: now)
        let free = slots(in: items)
        #expect(free.count == 1)
        #expect(free[0].label == .until(Fixture.at(9, 30)))
        #expect(free[0].canBook)
        #expect(free[0].bookableStart == now)
        #expect(items.map(\.id) == [free[0].id, standup.id])
    }

    @Test func aShortMorningIsHidden() {
        let standup = Fixture.event("Standup", Fixture.at(9, 30), Fixture.at(10, 0))
        #expect(slots(in: agenda([standup], now: Fixture.at(9, 20))).isEmpty)
    }

    @Test func aMorningThatAlreadyStartedIsHidden() {
        let standup = Fixture.event("Standup", Fixture.at(9, 30), Fixture.at(10, 0))
        #expect(slots(in: agenda([standup], now: Fixture.at(10, 0))).isEmpty)
    }

    @Test func aLaterDayDoesNotInventAMorningFromMidnight() {
        let tomorrow = Fixture.at(0, 0, day: 16)
        let standup = Fixture.event("Standup", Fixture.at(10, 0, day: 16), Fixture.at(10, 30, day: 16))
        let items = agenda([standup], now: Fixture.at(18, 0), on: tomorrow)
        #expect(slots(in: items).isEmpty)
        #expect(items.map(\.id) == [standup.id])
    }

    @Test func gapBetweenMeetingsShowsItsLength() {
        let now = Fixture.at(9, 0)
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(11, 0))
        let second = Fixture.event("B", Fixture.at(11, 30), Fixture.at(12, 0))
        let free = slots(in: agenda([first, second], now: now))
        // Morning until 10:00, then 30 minutes between them. Nothing after the last meeting.
        #expect(free.map(\.label) == [.until(Fixture.at(10, 0)), .duration(30 * 60)])
        #expect(free[1].isLong == false)
    }

    @Test func aLongGapIsMarkedLongAndABackToBackGapIsAbsent() {
        let now = Fixture.at(9, 0)
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(11, 0))
        let second = Fixture.event("B", Fixture.at(11, 0), Fixture.at(12, 0))
        let third = Fixture.event("C", Fixture.at(16, 0), Fixture.at(17, 0))
        let free = slots(in: agenda([first, second, third], now: now))
        let between = free.filter { if case .duration = $0.label { true } else { false } }
        #expect(between.count == 1)
        #expect(between[0].label == .duration(4 * 3_600))
        #expect(between[0].isLong)
    }

    @Test func lessThanFifteenMinutesIsNotAGap() {
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(11, 0))
        let second = Fixture.event("B", Fixture.at(11, 10), Fixture.at(12, 0))
        let free = slots(in: agenda([first, second], now: Fixture.at(11, 0)))
        #expect(free.isEmpty)
    }

    @Test func standingInAGapSaysFreeUntilAndDropsItWhenLittleIsLeft() {
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(11, 0))
        let second = Fixture.event("B", Fixture.at(13, 0), Fixture.at(14, 0))
        let open = slots(in: agenda([first, second], now: Fixture.at(11, 10)))
        #expect(open.count == 1)
        #expect(open[0].label == .until(Fixture.at(13, 0)))
        #expect(open[0].bookableStart == Fixture.at(11, 10))
        #expect(open[0].isLong)
        #expect(slots(in: agenda([first, second], now: Fixture.at(12, 50))).isEmpty)
    }

    @Test func aPastGapIsHidden() {
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(11, 0))
        let second = Fixture.event("B", Fixture.at(12, 0), Fixture.at(13, 0))
        #expect(slots(in: agenda([first, second], now: Fixture.at(13, 0))).isEmpty)
    }

    @Test func allDayEventsDoNotEatTheDay() {
        let holiday = Fixture.event("Holiday", Fixture.at(0, 0), Fixture.at(0, 0, day: 16), isAllDay: true)
        let meeting = Fixture.event("Sync", Fixture.at(15, 0), Fixture.at(16, 0))
        let items = agenda([holiday, meeting], now: Fixture.at(8, 0))
        #expect(items.count == 3)
        guard case .event(let first) = items[0], case .free(let slot) = items[1], case .event = items[2] else {
            Issue.record("expected holiday, free, meeting")
            return
        }
        #expect(first.title == "Holiday")
        #expect(slot.label == .until(Fixture.at(15, 0)))
    }

    @Test func overlappingMeetingsEndTheGapAtTheLaterOne() {
        let now = Fixture.at(9, 0)
        let left = Fixture.event("Left", Fixture.at(14, 0), Fixture.at(15, 0))
        let right = Fixture.event("Right", Fixture.at(14, 30), Fixture.at(15, 30))
        let next = Fixture.event("Next", Fixture.at(16, 0), Fixture.at(16, 30))
        let items = agenda([left, right, next], now: now)
        let between = slots(in: items).filter { if case .duration = $0.label { true } else { false } }
        #expect(between.count == 1)
        #expect(between[0].label == .duration(30 * 60))
        #expect(items.contains { if case .overlap = $0 { true } else { false } })
    }

    @Test func turningFreeTimeOffKeepsTheMeetings() {
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(11, 0))
        let second = Fixture.event("B", Fixture.at(12, 0), Fixture.at(13, 0))
        let items = agenda([first, second], now: Fixture.at(9, 0), includeFree: false)
        #expect(slots(in: items).isEmpty)
        #expect(items.map(\.id) == [first.id, second.id])
    }

    @Test func offersFocusLunchAndAShortMeeting() {
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(12, 0))
        let second = Fixture.event("B", Fixture.at(14, 0), Fixture.at(15, 0))
        let slot = slots(in: agenda([first, second], now: Fixture.at(9, 0))).last
        let offer = slot.flatMap { FreeTime.offer(for: $0, calendar: calendar) }
        #expect(offer?.focus == DateInterval(start: Fixture.at(12, 0), end: Fixture.at(14, 0)))
        #expect(offer?.lunch == DateInterval(start: Fixture.at(12, 0), end: Fixture.at(13, 0)))
        #expect(offer?.meeting == DateInterval(start: Fixture.at(12, 0), duration: 30 * 60))
    }

    @Test func lunchIsHiddenOutsideTheMiddleOfTheDayAndWhenTheOverlapIsShort() {
        let block = Fixture.event("Block", Fixture.at(16, 0), Fixture.at(17, 0))
        let evening = Fixture.event("Late", Fixture.at(18, 0), Fixture.at(19, 0))
        let eveningSlot = slots(in: agenda([block, evening], now: Fixture.at(9, 0))).last
        #expect(eveningSlot.flatMap { FreeTime.offer(for: $0, calendar: calendar) }?.lunch == nil)

        let before = Fixture.event("Before", Fixture.at(13, 0), Fixture.at(14, 45))
        let after = Fixture.event("After", Fixture.at(15, 10), Fixture.at(16, 0))
        let tight = slots(in: agenda([before, after], now: Fixture.at(9, 0))).last
        let offer = tight.flatMap { FreeTime.offer(for: $0, calendar: calendar) }
        #expect(offer?.lunch == nil)
        #expect(offer?.meeting == DateInterval(start: Fixture.at(14, 45), end: Fixture.at(15, 10)))
    }

    @Test func theBlockIsSharedAndStartsAtThirtyMinutes() {
        let first = Fixture.event("A", Fixture.at(12, 0), Fixture.at(16, 0))
        let second = Fixture.event("B", Fixture.at(20, 0), Fixture.at(21, 0))
        let slot = slots(in: agenda([first, second], now: Fixture.at(9, 0))).last
        let opening = slot.map { FreeTime.placement(in: $0) }
        #expect(opening?.interval == DateInterval(start: Fixture.at(16, 0), end: Fixture.at(16, 30)))
        #expect(opening?.canMoveEarlier == false)
        #expect(opening?.canMoveLater == true)
        let hour = slot.flatMap { FreeTime.placement(in: $0, length: .fixed(60 * 60)).interval }
        #expect(hour == DateInterval(start: Fixture.at(16, 0), end: Fixture.at(17, 0)))
        let rest = slot.map { FreeTime.placement(in: $0, length: .untilEnd) }
        #expect(rest?.interval == DateInterval(start: Fixture.at(16, 0), end: Fixture.at(20, 0)))
        let later = slot.flatMap { FreeTime.shiftedStart(in: $0, from: Fixture.at(16, 0), length: .untilEnd, forward: true) }
        #expect(later == Fixture.at(16, 30))
        let stillOpen = slot.flatMap { FreeTime.placement(in: $0, preferredStart: later, length: .untilEnd).interval }
        #expect(stillOpen == DateInterval(start: Fixture.at(16, 30), end: Fixture.at(20, 0)))
        let last = slot.map { FreeTime.placement(in: $0, preferredStart: Fixture.at(19, 30)) }
        #expect(last?.interval == DateInterval(start: Fixture.at(19, 30), end: Fixture.at(20, 0)))
        #expect(last?.canMoveLater == false)
        let nearTheEnd = slot.map { FreeTime.placement(in: $0, preferredStart: Fixture.at(19, 0)) }
        #expect(nearTheEnd?.choices.contains(.fixed(2 * 60 * 60)) == false)
        #expect(nearTheEnd?.choices.contains(.fixed(60 * 60)) == true)
        let tooLate = slot.flatMap { FreeTime.placement(in: $0, preferredStart: Fixture.at(22, 0)).interval }
        #expect(tooLate?.start == Fixture.at(19, 30))
    }

    @Test func aShortGapIsTheWholeBlock() {
        let first = Fixture.event("A", Fixture.at(14, 0), Fixture.at(14, 40))
        let second = Fixture.event("B", Fixture.at(15, 0), Fixture.at(16, 0))
        let slot = slots(in: agenda([first, second], now: Fixture.at(9, 0))).last
        let placed = slot.map { FreeTime.placement(in: $0) }
        #expect(placed?.interval == DateInterval(start: Fixture.at(14, 40), end: Fixture.at(15, 0)))
        #expect(placed?.length == .fixed(20 * 60))
        #expect(placed?.canMoveEarlier == false)
        #expect(placed?.canMoveLater == false)
        #expect(placed?.choices == [.untilEnd])
    }

    @Test func aShorterLunchStopsAtThirtyMinutes() {
        let first = Fixture.event("A", Fixture.at(10, 0), Fixture.at(12, 0))
        let second = Fixture.event("B", Fixture.at(14, 0), Fixture.at(15, 0))
        let slot = slots(in: agenda([first, second], now: Fixture.at(9, 0))).last
        let offer = slot.flatMap { FreeTime.offer(for: $0, calendar: calendar, lunchLength: 30 * 60) }
        #expect(offer?.lunch == DateInterval(start: Fixture.at(12, 0), end: Fixture.at(12, 30)))
    }

    @Test func lunchFillsAtMostAnHourInsideTheWindow() {
        let first = Fixture.event("A", Fixture.at(9, 0), Fixture.at(11, 0))
        let second = Fixture.event("B", Fixture.at(16, 0), Fixture.at(17, 0))
        let slot = slots(in: agenda([first, second], now: Fixture.at(8, 0))).last
        let offer = slot.flatMap { FreeTime.offer(for: $0, calendar: calendar) }
        #expect(offer?.lunch == DateInterval(start: Fixture.at(11, 30), end: Fixture.at(12, 30)))
    }
}
