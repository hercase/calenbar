import Foundation
import Testing

@testable import CalenbarCore

struct WidthProbeTests {
    let now = Fixture.at(10, 0)

    @Test func dueRightAwayAtFirst() {
        #expect(WidthProbe().isDue(now: now))
    }

    @Test func waitsLongerAfterEachTryThatDoesNotFit() {
        var probe = WidthProbe()
        probe.didNotFit(now: now)
        #expect(!probe.isDue(now: Fixture.at(10, 9)))
        #expect(probe.isDue(now: Fixture.at(10, 10)))
        probe.didNotFit(now: Fixture.at(10, 10))
        #expect(!probe.isDue(now: Fixture.at(10, 29)))
        #expect(probe.isDue(now: Fixture.at(10, 30)))
    }

    @Test func waitIsCapped() {
        #expect(WidthProbe.delay(afterFailures: 1) == 10 * 60)
        #expect(WidthProbe.delay(afterFailures: 3) == 40 * 60)
        #expect(WidthProbe.delay(afterFailures: 20) == WidthProbe.longestRetry)
    }

    @Test func fittingStartsOver() {
        var probe = WidthProbe()
        probe.didNotFit(now: now)
        probe.didNotFit(now: now)
        probe.fit()
        #expect(probe.isDue(now: now))
        probe.didNotFit(now: now)
        #expect(probe.isDue(now: Fixture.at(10, 10)))
    }

    @Test func shrinkingOnItsOwnHoldsOffWithoutGrowingTheWait() {
        var probe = WidthProbe()
        probe.shrank(now: now)
        #expect(!probe.isDue(now: Fixture.at(10, 9)))
        #expect(probe.isDue(now: Fixture.at(10, 10)))
        #expect(probe.failures == 0)
    }

    @Test func shrinkingNeverShortensALongerWait() {
        var probe = WidthProbe()
        for _ in 0..<3 { probe.didNotFit(now: now) }
        probe.shrank(now: now)
        #expect(!probe.isDue(now: Fixture.at(10, 39)))
    }

    @Test func widerStepsUpToTheCeiling() {
        #expect(WidthProbe.wider(than: 60, step: 40, narrowest: 60, ceiling: 160) == 100)
        #expect(WidthProbe.wider(than: 140, step: 40, narrowest: 60, ceiling: 160) == 160)
        #expect(WidthProbe.wider(than: 160, step: 40, narrowest: 60, ceiling: 160) == nil)
        #expect(WidthProbe.wider(than: nil, step: 40, narrowest: 60, ceiling: 160) == 60)
    }
}
