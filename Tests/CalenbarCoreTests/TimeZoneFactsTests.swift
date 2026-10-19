import Foundation
import Testing

@testable import CalenbarCore

struct TimeZoneFactsTests {
    private let october = Fixture.at(12, 0)  // 2026-10-15 12:00 UTC
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let kolkata = TimeZone(identifier: "Asia/Kolkata")!

    @Test func utcOffsetsReadLikePeopleWriteThem() {
        #expect(TimeZoneFacts.utcOffsetText(of: losAngeles, at: october) == "UTC\u{2212}7")
        #expect(TimeZoneFacts.utcOffsetText(of: kolkata, at: october) == "UTC+5:30")
        #expect(TimeZoneFacts.utcOffsetText(of: TimeZone(identifier: "GMT")!, at: october) == "UTC")
    }

    @Test func abbreviationFollowsDaylightSaving() {
        #expect(TimeZoneFacts.abbreviation(of: losAngeles, at: october) == "PDT")
        #expect(
            TimeZoneFacts.abbreviation(of: losAngeles, at: Fixture.at(12, 0, day: 1).addingTimeInterval(45 * 86_400)) == "PST")
    }

    @Test func clockChangeIsAnnouncedOnlyWhenClose() {
        // US clocks fall back on 2026-11-01: 17 days after the reference, one hour back.
        let change = TimeZoneFacts.upcomingClockChange(in: losAngeles, at: october)
        #expect(change?.hourShift == -1)
        #expect(TimeZoneFacts.upcomingClockChange(in: losAngeles, at: october, within: 7) == nil)
        #expect(TimeZoneFacts.upcomingClockChange(in: kolkata, at: october) == nil)
    }
}
