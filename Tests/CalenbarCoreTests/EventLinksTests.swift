import Foundation
import Testing

@testable import CalenbarCore

struct GoogleCalendarLinkTests {
    let start = Fixture.at(13, 0, day: 16)

    @Test func primaryCalendarEventOpensTheEventItself() {
        let url = GoogleCalendarLink.url(
            externalID: "abc123@google.com",
            calendarTitle: "me@deptagency.com",
            start: start,
            isRecurring: false
        )
        #expect(url?.absoluteString == "https://calendar.google.com/calendar/event?eid=YWJjMTIzIG1lQGRlcHRhZ2VuY3kuY29t")
    }

    @Test func recurringOccurrenceIncludesItsStartInUTC() {
        let url = GoogleCalendarLink.url(
            externalID: "abc123@google.com",
            calendarTitle: "me@deptagency.com",
            start: start,
            isRecurring: true
        )
        #expect(
            url?.absoluteString
                == "https://calendar.google.com/calendar/event?eid=YWJjMTIzXzIwMjYxMDE2VDEzMDAwMFogbWVAZGVwdGFnZW5jeS5jb20")
    }

    @Test func otherCalendarsFallBackToTheDayView() {
        let url = GoogleCalendarLink.url(
            externalID: "abc123@google.com",
            calendarTitle: "Team Events",
            start: start,
            isRecurring: false
        )
        #expect(url?.absoluteString == "https://calendar.google.com/calendar/r/day/2026/10/16")
    }

    @Test func nonGoogleEventsHaveNoLink() {
        #expect(
            GoogleCalendarLink.url(externalID: "1234-ABCD", calendarTitle: "me@x.com", start: start, isRecurring: false) == nil)
        #expect(GoogleCalendarLink.isGoogleEvent(externalID: "abc@google.com"))
        #expect(!GoogleCalendarLink.isGoogleEvent(externalID: "1234-ABCD"))
    }
}

struct AttendeeTests {
    func event(_ attendees: [Attendee], myStatus: ParticipationStatus = .accepted) -> CalendarEvent {
        Fixture.event("Sync", Fixture.at(11, 0), Fixture.at(12, 0), attendees: attendees, myStatus: myStatus)
    }

    @Test func pendingInvitationNeedsResponse() {
        #expect(event([], myStatus: .pending).needsResponse)
        #expect(!event([], myStatus: .accepted).needsResponse)
        #expect(!event([], myStatus: .unknown).needsResponse)
    }

    @Test func roomsAreSeparatedFromPeople() {
        let sut = event([
            Attendee(name: "Ana", email: "ana@x.com", status: .accepted, kind: .person, isCurrentUser: false, isOrganizer: true),
            Attendee(
                name: "BA-4-Lobby (8)", email: nil, status: .accepted, kind: .room, isCurrentUser: false, isOrganizer: false),
            Attendee(name: "Me", email: "me@x.com", status: .pending, kind: .person, isCurrentUser: true, isOrganizer: false),
        ])
        #expect(sut.rooms == ["BA-4-Lobby (8)"])
        #expect(sut.people.map(\.name) == ["Ana", "Me"])
        #expect(sut.organizer?.name == "Ana")
    }

    @Test func displayNameFallsBackToEmail() {
        let nameless = Attendee(
            name: nil, email: "bob@x.com", status: .pending, kind: .person, isCurrentUser: false, isOrganizer: false)
        #expect(nameless.displayName == "bob@x.com")
    }
}
