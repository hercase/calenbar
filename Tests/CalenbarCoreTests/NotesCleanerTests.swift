import Testing

@testable import CalenbarCore

struct NotesCleanerTests {
    @Test func plainTextIsTrimmed() {
        #expect(NotesCleaner.clean("  Agenda: review Q4  \n") == "Agenda: review Q4")
    }

    @Test func htmlTagsBecomeLineBreaksAndText() {
        let html = "<p>Hi team,</p><br><b>Agenda</b>:<ul><li>Roadmap</li><li>Hiring</li></ul>"
        #expect(NotesCleaner.clean(html) == "Hi team,\nAgenda:\nRoadmap\nHiring")
    }

    @Test func entitiesAreDecoded() {
        #expect(NotesCleaner.clean("Q&amp;A&nbsp;session &lt;3 &quot;fun&quot; it&#39;s") == "Q&A session <3 \"fun\" it's")
    }

    @Test func blankLinesCollapse() {
        #expect(NotesCleaner.clean("One\n\n\n\nTwo\n \n") == "One\n\nTwo")
    }

    @Test func googleMeetInvitationFooterIsRemoved() {
        let notes = """
            • What you're working on today

            -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-
            Join with Google Meet: https://meet.google.com/abc-defg-hij
            Learn more about Meet at: https://support.google.com/a/users/answer/9282720
            Please do not edit this section.
            -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-
            """
        #expect(NotesCleaner.clean(notes) == "• What you're working on today")
    }

    @Test func onlyAGoogleFooterIsNil() {
        #expect(NotesCleaner.clean("-::~:~::~:~:~::-\nJoin with Google Meet: https://meet.google.com/x") == nil)
    }

    @Test func emptyOrWhitespaceIsNil() {
        #expect(NotesCleaner.clean(nil) == nil)
        #expect(NotesCleaner.clean("  <br> ") == nil)
    }
}
