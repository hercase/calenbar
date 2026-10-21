import Foundation
import Testing

@testable import CalenbarCore

struct GoogleAccountURLTests {
    private func rewrite(_ string: String, _ email: EmailAddress? = EmailAddress("juan@empresa.com")) throws -> String {
        let url = try #require(URL(string: string))
        return GoogleAccountURL.url(url, signedInAs: try #require(email)).absoluteString
    }

    @Test func addsTheAccountToMeet() throws {
        #expect(
            try rewrite("https://meet.google.com/abc-defg-hij")
                == "https://meet.google.com/abc-defg-hij?authuser=juan@empresa.com")
    }

    @Test func replacesAnExistingAuthuser() throws {
        #expect(
            try rewrite("https://meet.google.com/abc-defg-hij?authuser=0")
                == "https://meet.google.com/abc-defg-hij?authuser=juan@empresa.com")
    }

    @Test func collapsesDuplicateAndOddlyCasedAuthusers() throws {
        #expect(
            try rewrite("https://meet.google.com/abc?AuthUser=1&authuser=2&auth%75ser=3")
                == "https://meet.google.com/abc?authuser=juan@empresa.com")
    }

    @Test func keepsOtherParametersInOrderAndTheFragment() throws {
        #expect(
            try rewrite("https://meet.google.com/abc?hs=122&authuser=0&pli=1#top")
                == "https://meet.google.com/abc?hs=122&pli=1&authuser=juan@empresa.com#top")
    }

    @Test func encodesPlusSoGoogleDoesNotReadASpace() throws {
        #expect(
            try rewrite("https://meet.google.com/abc", EmailAddress("juan+meet@empresa.com"))
                == "https://meet.google.com/abc?authuser=juan%2Bmeet@empresa.com")
    }

    @Test func encodesApostrophes() throws {
        #expect(
            try rewrite("https://meet.google.com/abc", EmailAddress("o'brien@empresa.ie"))
                == "https://meet.google.com/abc?authuser=o%27brien@empresa.ie")
    }

    @Test func isIdempotent() throws {
        let once = try rewrite("https://meet.google.com/abc?hs=1")
        #expect(try rewrite(once) == once)
    }

    @Test func hostIsCaseInsensitive() throws {
        #expect(try rewrite("https://MEET.Google.com/abc").hasSuffix("?authuser=juan@empresa.com"))
    }

    @Test func coversGoogleCalendarOnTheWeb() throws {
        #expect(
            try rewrite("https://calendar.google.com/calendar/event?eid=abc")
                == "https://calendar.google.com/calendar/event?eid=abc&authuser=juan@empresa.com")
        #expect(try rewrite("https://calendar.google.com/calendar/r/day/2026/10/21").hasSuffix("?authuser=juan@empresa.com"))
    }

    /// The address must never reach a host that isn't Google's Meet or Calendar, nor travel unencrypted.
    @Test(arguments: [
        "http://meet.google.com/abc",
        "https://meet.google.com.evil.com/abc",
        "https://evilmeet.google.com/abc",
        "https://meet.google.co/abc",
        "https://google.com/abc",
        "https://accounts.google.com/abc",
        "https://mail.google.com/abc",
        "https://zoom.us/j/123",
        "https://teams.microsoft.com/l/meetup-join/x",
        "https://evil.com/?next=https://meet.google.com/abc",
        "https://meet.google.com@evil.com/abc",
        "https://user:pass@meet.google.com/abc",
        "zoommtg://zoom.us/join?confno=1",
        "meet.google.com/abc",
    ])
    func leavesOtherLinksAlone(_ string: String) throws {
        #expect(try rewrite(string) == string)
    }
}
