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
    }

    @Test func flashesFiveTimesAtEndOfEachMinuteInLastFive() {
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
