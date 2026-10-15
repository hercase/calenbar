import Foundation
import Testing

@testable import CalenbarCore

struct MeetingLinkDetectorTests {
    @Test func zoomWithPasswordGetsNativeURL() throws {
        let link = try #require(
            MeetingLinkDetector.detect(
                url: nil,
                location: "https://deptagency.zoom.us/j/81234567890?pwd=abc123",
                notes: nil
            ))
        #expect(link.provider == .zoom)
        #expect(link.webURL.absoluteString == "https://deptagency.zoom.us/j/81234567890?pwd=abc123")
        #expect(link.nativeURL?.absoluteString == "zoommtg://deptagency.zoom.us/join?confno=81234567890&pwd=abc123")
    }

    @Test func zoomWithoutPassword() throws {
        let link = try #require(MeetingLinkDetector.detect(url: nil, location: "https://zoom.us/j/123", notes: nil))
        #expect(link.nativeURL?.absoluteString == "zoommtg://zoom.us/join?confno=123")
    }

    @Test func zoomGov() throws {
        let link = try #require(
            MeetingLinkDetector.detect(url: nil, location: nil, notes: "Join: https://agency.zoomgov.com/j/555"))
        #expect(link.provider == .zoom)
    }

    @Test func teamsMeetupJoinGetsNativeScheme() throws {
        let web = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d"
        let link = try #require(MeetingLinkDetector.detect(url: nil, location: nil, notes: "Click here \(web) to join"))
        #expect(link.provider == .teams)
        #expect(link.nativeURL?.absoluteString.hasPrefix("msteams://teams.microsoft.com/l/meetup-join/") == true)
    }

    @Test func googleMeetFromEventURL() throws {
        let link = try #require(
            MeetingLinkDetector.detect(url: URL(string: "https://meet.google.com/abc-defg-hij"), location: nil, notes: nil))
        #expect(link.provider == .googleMeet)
        #expect(link.nativeURL == nil)
    }

    @Test func meetingLinkInNotesBeatsGenericLinkInLocation() throws {
        let link = try #require(
            MeetingLinkDetector.detect(
                url: nil,
                location: "https://maps.google.com/?q=office",
                notes: "Docs: https://example.com/doc\nJoin https://meet.google.com/xyz-abcd-efg"
            ))
        #expect(link.provider == .googleMeet)
    }

    @Test func genericLinkIsNotAMeeting() {
        #expect(MeetingLinkDetector.detect(url: nil, location: "https://example.com", notes: nil) == nil)
    }

    @Test func noLinks() {
        #expect(MeetingLinkDetector.detect(url: nil, location: "Room 4B", notes: "Bring laptop") == nil)
    }

    @Test func lookalikeDomainIsRejected() {
        #expect(MeetingLinkDetector.detect(url: nil, location: "https://zoom.us.evil.com/j/1", notes: nil) == nil)
    }

    @Test func slackHuddleRequiresHuddlePath() {
        #expect(MeetingLinkDetector.detect(url: nil, location: "https://app.slack.com/client/T1/C1", notes: nil) == nil)
        let link = MeetingLinkDetector.detect(url: nil, location: "https://app.slack.com/huddle/T1/C1", notes: nil)
        #expect(link?.provider == .slack)
    }
}
