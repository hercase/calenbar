import Foundation
import Testing

@testable import CalenbarCore

struct DurationFormatTests {
    static let cases: [(Double, String)] = [
        (60, "1m"), (59, "1m"), (1_800, "30m"), (3_600, "1h"),
        (3_840, "1h 4m"), (3_810, "1h 4m"), (7_200, "2h"),
    ]

    @Test(arguments: cases)
    func compact(seconds: Double, expected: String) {
        #expect(TitleFormatter.compactDuration(seconds) == expected)
    }
}

struct TitleFormatterTests {
    let event = Fixture.event("Class with Hernán!", Fixture.at(15, 0), Fixture.at(16, 0))

    @Test func upcomingShowsIn() {
        #expect(TitleFormatter.suffix(for: event, now: Fixture.at(13, 56)) == "in 1h 4m")
        #expect(TitleFormatter.suffix(for: event, now: Fixture.at(14, 50)) == "in 10m")
    }

    @Test func firstMinuteOfOngoingShowsNow() {
        #expect(TitleFormatter.suffix(for: event, now: Fixture.at(15, 0)) == "now")
        #expect(TitleFormatter.suffix(for: event, now: Fixture.at(15, 0, 59)) == "now")
    }

    @Test func ongoingShowsTimeLeft() {
        #expect(TitleFormatter.suffix(for: event, now: Fixture.at(15, 35)) == "25m left")
        #expect(TitleFormatter.suffix(for: event, now: Fixture.at(15, 1)) == "59m left")
    }

    @Test func titleJoinsWithThinSpacedBullet() {
        #expect(TitleFormatter.title(for: event, now: Fixture.at(14, 50)) == "Class with Hernán!\u{2009}•\u{2009}in 10m")
    }

    @Test func untitledEventGetsPlaceholder() {
        let untitled = Fixture.event("", Fixture.at(15, 0), Fixture.at(16, 0))
        #expect(TitleFormatter.displayTitle(untitled) == "(No title)")
    }

    @Test func panelStatusIsSentenceCase() {
        #expect(TitleFormatter.status(for: event, now: Fixture.at(13, 58)) == "In 1h 2m")
        #expect(TitleFormatter.status(for: event, now: Fixture.at(15, 0, 30)) == "Now")
        #expect(TitleFormatter.status(for: event, now: Fixture.at(15, 48)) == "Ends in 12m")
    }
}

struct RelativeTimeTests {
    let start = Fixture.at(15, 0)

    @Test func elapsedReadsLikeTheClock() {
        // The minute tick lands just after the boundary; 3:03 must still read 3, not 4.
        #expect(RelativeTime.since(start, now: Fixture.at(15, 3).addingTimeInterval(0.05)) == "3m")
        #expect(RelativeTime.since(start, now: Fixture.at(15, 3, 59)) == "3m")
        #expect(RelativeTime.since(start, now: Fixture.at(15, 1)) == "1m")
        #expect(RelativeTime.since(start, now: Fixture.at(16, 4)) == "1h 4m")
    }

    @Test func elapsedToleratesAnEarlyTick() {
        #expect(RelativeTime.minutesSince(start, now: Fixture.at(15, 3).addingTimeInterval(-0.3)) == 3)
    }

    @Test func elapsedIsZeroInTheFirstMinute() {
        #expect(RelativeTime.minutesSince(start, now: start) == 0)
        #expect(RelativeTime.minutesSince(start, now: Fixture.at(15, 0, 58)) == 0)
    }

    @Test func countdownCountsTheMinuteInProgress() {
        #expect(RelativeTime.until(start, now: Fixture.at(14, 57).addingTimeInterval(0.05)) == "3m")
        #expect(RelativeTime.until(start, now: Fixture.at(14, 57, 30)) == "3m")
        #expect(RelativeTime.until(start, now: Fixture.at(14, 57).addingTimeInterval(-0.3)) == "3m")
        #expect(RelativeTime.until(start, now: Fixture.at(14, 59, 59)) == "1m")
    }
}

struct TitleWidthFitterTests {
    // One point per character keeps the arithmetic obvious.
    let measure: (String) -> Double = { Double($0.count) }

    @Test func fitsUnchangedWhenShortEnough() {
        let fitted = TitleWidthFitter.fit(title: "Standup", suffix: "in 5m", maxWidth: 100, measure: measure)
        #expect(fitted == "Standup\u{2009}•\u{2009}in 5m")
    }

    @Test func truncatesTitleButNeverSuffix() {
        let fitted = TitleWidthFitter.fit(title: "Career Support that Fits", suffix: "in 5m", maxWidth: 16, measure: measure)
        #expect(fitted.hasSuffix("\u{2009}•\u{2009}in 5m"))
        #expect(fitted.hasPrefix("Career"))
        #expect(fitted.contains("…"))
        #expect(measure(fitted) <= 16)
    }

    @Test func keepsSuffixEvenWhenNoRoomForTitle() {
        let fitted = TitleWidthFitter.fit(title: "Anything", suffix: "in 5m", maxWidth: 3, measure: measure)
        #expect(fitted == "in 5m")
    }
}
