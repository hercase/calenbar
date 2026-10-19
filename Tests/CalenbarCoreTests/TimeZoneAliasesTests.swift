import Foundation
import Testing

@testable import CalenbarCore

struct TimeZoneAliasesTests {
    @Test func commonAbbreviationsResolve() {
        #expect(TimeZoneAliases.identifier(for: "ET") == "America/New_York")
        #expect(TimeZoneAliases.identifier(for: " pt ") == "America/Los_Angeles")
        #expect(TimeZoneAliases.identifier(for: "cet") == "Europe/Berlin")
        #expect(TimeZoneAliases.identifier(for: "utc") == "GMT")
        #expect(TimeZoneAliases.identifier(for: "ART") == "America/Argentina/Buenos_Aires")
    }

    @Test func foundationAbbreviationsAreTheFallback() {
        #expect(TimeZoneAliases.identifier(for: "MSK") != nil)
    }

    @Test func wordsThatAreNotAbbreviationsGiveNothing() {
        #expect(TimeZoneAliases.identifier(for: "Standart") == nil)
        #expect(TimeZoneAliases.identifier(for: "") == nil)
    }
}
