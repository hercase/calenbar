import Foundation
import Testing

@testable import CalenbarCore

struct AttentionPolicyTests {
    let start = Fixture.at(15, 0)

    func flash(_ hour: Int, _ minute: Int, _ second: Int, fromFiveMinutes: Bool = true) -> Bool {
        AttentionPolicy.isFlashOn(start: start, now: Fixture.at(hour, minute, second), fromFiveMinutes: fromFiveMinutes)
    }

    @Test func quietMoreThanFiveMinutesAway() {
        #expect(!flash(14, 53, 55))
        // 5m 59s left still reads "in 6m" because the menu bar rounds up.
        #expect(!flash(14, 54, 1))
    }

    @Test func flashesFiveTimesAtEndOfEachMinuteInLastFive() {
        // 4m 59s left reads "in 5m"; that is the first burst.
        #expect((0..<60).filter { flash(14, 55, $0) } == [1, 3, 5, 7, 9])
        // During 14:56 the time left goes 4m 0s → 3m 1s; flashes at 3m 59s, 57s, 55s, 53s, 51s left.
        let onSeconds = (0..<60).filter { flash(14, 56, $0) }
        #expect(onSeconds == [1, 3, 5, 7, 9])
    }

    @Test func noMinuteFlashesWhenFromFiveMinutesIsOff() {
        #expect((0..<60).filter { flash(14, 56, $0, fromFiveMinutes: false) }.isEmpty)
    }

    @Test func flashesContinuouslyInLastThirtySeconds() {
        let onSeconds = (30..<60).filter { flash(14, 59, $0, fromFiveMinutes: false) }
        #expect(onSeconds.count == 15)
        #expect(!flash(14, 59, 20, fromFiveMinutes: false))
    }

    @Test func quietOnceStarted() {
        #expect(!flash(15, 0, 1))
    }

    @Test func soundAtFiveMinutesAndThirtySeconds() {
        #expect(AttentionPolicy.shouldPing(start: start, now: Fixture.at(14, 55), fromFiveMinutes: true))
        #expect(!AttentionPolicy.shouldPing(start: start, now: Fixture.at(14, 55), fromFiveMinutes: false))
        #expect(AttentionPolicy.shouldPing(start: start, now: Fixture.at(14, 59, 30), fromFiveMinutes: false))
        #expect(!AttentionPolicy.shouldPing(start: start, now: Fixture.at(14, 58), fromFiveMinutes: true))
    }

    @Test func needsSecondTicksOnlyCloseToStart() {
        #expect(AttentionPolicy.needsSecondTicks(start: start, now: Fixture.at(14, 54, 30)))
        #expect(!AttentionPolicy.needsSecondTicks(start: start, now: Fixture.at(14, 50)))
        #expect(!AttentionPolicy.needsSecondTicks(start: start, now: Fixture.at(15, 1)))
    }
}

struct FollowUpAttentionTests {
    let next = Fixture.at(13, 30)

    func flash(_ hour: Int, _ minute: Int, _ second: Int) -> Bool {
        AttentionPolicy.isFollowUpFlashOn(start: next, now: Fixture.at(hour, minute, second))
    }

    @Test func flashesOnceTenMinutesBefore() {
        // 9m 59s → 9m 51s left: the same five-flash burst as the red ones.
        #expect((0..<60).filter { flash(13, 20, $0) } == [1, 3, 5, 7, 9])
    }

    @Test func quietOtherwise() {
        #expect((0..<60).allSatisfy { !flash(13, 19, $0) })
        #expect((0..<60).allSatisfy { !flash(13, 21, $0) })
        #expect((0..<60).allSatisfy { !flash(13, 25, $0) })
    }

    @Test func ticksOnlyAroundTheBurst() {
        #expect(!AttentionPolicy.needsFollowUpTicks(start: next, now: Fixture.at(13, 18, 59)))
        #expect(AttentionPolicy.needsFollowUpTicks(start: next, now: Fixture.at(13, 19, 0)))
        #expect(AttentionPolicy.needsFollowUpTicks(start: next, now: Fixture.at(13, 20, 30)))
        #expect(!AttentionPolicy.needsFollowUpTicks(start: next, now: Fixture.at(13, 21, 0)))
    }

    @Test func namesTheNextMeetingWhileTheBurstRunsAndJustAfter() {
        func names(_ minute: Int, _ second: Int) -> Bool {
            AttentionPolicy.showsFollowUpTitle(start: next, now: Fixture.at(13, minute, second))
        }
        #expect(!names(19, 59))  // 10m 1s left: not yet
        #expect(names(20, 0))  // 10m left
        #expect(names(20, 9))  // inside the burst
        #expect(names(20, 30))  // after it, long enough to read
        #expect(names(20, 39))  // 9m 21s left: last second of the window
        #expect(!names(20, 40))  // 9m 20s left: back to the ongoing meeting
    }
}
