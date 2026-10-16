import Foundation
import Testing

@testable import CalenbarCore

struct TimeZoneMathTests {
    let buenosAires = TimeZone(identifier: "America/Argentina/Buenos_Aires")!  // UTC-3, no DST
    let madrid = TimeZone(identifier: "Europe/Madrid")!  // UTC+1 / +2 in summer
    let kolkata = TimeZone(identifier: "Asia/Kolkata")!  // UTC+5:30
    let auckland = TimeZone(identifier: "Pacific/Auckland")!  // UTC+12 / +13 in summer
    let utc = TimeZone(identifier: "UTC")!

    @Test func offsetTextUsesHoursAndMinutes() {
        let noon = Fixture.at(12, 0)  // October: Madrid is still on summer time (+2).
        #expect(TimeZoneMath.offsetText(of: madrid, from: buenosAires, at: noon) == "+5h")
        #expect(TimeZoneMath.offsetText(of: kolkata, from: buenosAires, at: noon) == "+8h 30m")
        #expect(TimeZoneMath.offsetText(of: buenosAires, from: madrid, at: noon) == "-5h")
        #expect(TimeZoneMath.offsetText(of: utc, from: utc, at: noon) == nil)
    }

    @Test func offsetFollowsDaylightSaving() {
        let january = Fixture.calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        #expect(TimeZoneMath.offsetText(of: madrid, from: buenosAires, at: january) == "+4h")
    }

    @Test func dayDifferenceAcrossMidnight() {
        // 23:30 in Buenos Aires on the 15th is 03:30 on the 16th in UTC and 15:30 on the 16th in Auckland.
        let lateEvening = Fixture.calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 2, minute: 30))!
        #expect(TimeZoneMath.dayDifference(in: auckland, from: buenosAires, at: lateEvening) == 1)
        #expect(TimeZoneMath.dayDifference(in: buenosAires, from: auckland, at: lateEvening) == -1)
        #expect(TimeZoneMath.dayDifference(in: madrid, from: utc, at: Fixture.at(12, 0)) == 0)
    }

    @Test func daytimeWindow() {
        // 10:00 UTC = 07:00 in Buenos Aires (day) and 23:00 in Auckland (night).
        let morning = Fixture.at(10, 0)
        #expect(TimeZoneMath.isDaytime(in: buenosAires, at: morning))
        #expect(!TimeZoneMath.isDaytime(in: auckland, at: morning))
    }
}
