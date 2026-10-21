import Foundation
import Testing

@testable import CalenbarCore

struct MeetingLaunchPlannerTests {
    private static let chrome = "com.google.Chrome"
    private static let firefox = "org.mozilla.firefox"
    private static let work = EmailAddress("juan@empresa.com")
    private static let chromeProfiles = [
        BrowserProfile(id: "Default", name: "Personal", email: EmailAddress("juan@gmail.com")),
        BrowserProfile(id: "Profile 2", name: "Work", email: work),
        BrowserProfile(id: "Profile 3", name: "Client", email: nil),
    ]
    private static let firefoxProfiles = [
        BrowserProfile(id: "/ff/Profiles/a.Work", name: "Work", email: nil),
        BrowserProfile(id: "/ff/Profiles/b.Personal", name: "Personal", email: nil),
    ]

    private let meet = URL(string: "https://meet.google.com/abc-defg-hij")
    private let meetWithAccount = "https://meet.google.com/abc-defg-hij?authuser=juan@empresa.com"

    private func plan(
        _ url: URL?,
        native: URL? = nil,
        browser: String? = chrome,
        profiles: [BrowserProfile] = chromeProfiles,
        email: EmailAddress? = work,
        choice: ProfileChoice = .automatic
    ) throws -> LaunchPlan {
        let context = LaunchContext(browserBundleID: browser, profiles: profiles, accountEmail: email, choice: choice)
        return MeetingLaunchPlanner.plan(webURL: try #require(url), nativeURL: native, context: context)
    }

    private func chromiumPlan(_ url: String, profile: String) throws -> LaunchPlan {
        .browserProfile(try #require(URL(string: url)), arguments: ["--profile-directory=\(profile)", "--", url])
    }

    @Test func nativeAppWinsWithoutAccountOrProfile() throws {
        let native = try #require(URL(string: "zoommtg://zoom.us/join?confno=1"))
        #expect(try plan(URL(string: "https://zoom.us/j/1"), native: native) == .native(native))
    }

    @Test func meetInChromeOpensInTheAccountsProfile() throws {
        #expect(try plan(meet) == chromiumPlan(meetWithAccount, profile: "Profile 2"))
    }

    @Test func noProfileForTheAccountStillCarriesTheAccount() throws {
        let other = EmailAddress("juan@cliente.com")
        #expect(
            try plan(meet, email: other)
                == .browser(try #require(URL(string: "https://meet.google.com/abc-defg-hij?authuser=juan@cliente.com"))))
    }

    @Test func choosingNoProfileKeepsTheAccount() throws {
        #expect(try plan(meet, choice: .none) == .browser(try #require(URL(string: meetWithAccount))))
    }

    @Test func chosenProfileBeatsTheMatch() throws {
        #expect(
            try plan(meet, choice: .profile(bundleID: Self.chrome, id: "Profile 3"))
                == chromiumPlan(meetWithAccount, profile: "Profile 3"))
    }

    @Test func chosenProfileMatchesTheBrowserCaseInsensitively() throws {
        #expect(
            try plan(meet, choice: .profile(bundleID: "COM.GOOGLE.CHROME", id: "Default"))
                == chromiumPlan(meetWithAccount, profile: "Default"))
    }

    @Test func deletedChosenProfileFallsBackToTheMatch() throws {
        #expect(
            try plan(meet, choice: .profile(bundleID: Self.chrome, id: "Profile 7"))
                == chromiumPlan(meetWithAccount, profile: "Profile 2"))
    }

    @Test func choiceForAnotherBrowserIsIgnored() throws {
        let brave = "com.brave.Browser"
        #expect(
            try plan(meet, browser: brave, choice: .profile(bundleID: Self.chrome, id: "Profile 3"))
                == chromiumPlan(meetWithAccount, profile: "Profile 2"))
    }

    @Test func safariGetsTheAccountOnly() throws {
        #expect(try plan(meet, browser: "com.apple.Safari") == .browser(try #require(URL(string: meetWithAccount))))
    }

    @Test func unknownBrowserGetsTheAccountOnly() throws {
        #expect(try plan(meet, browser: nil) == .browser(try #require(URL(string: meetWithAccount))))
    }

    @Test func firefoxNeedsAChosenProfile() throws {
        #expect(
            try plan(meet, browser: Self.firefox, profiles: Self.firefoxProfiles)
                == .browser(try #require(URL(string: meetWithAccount))))
        let chosen = ProfileChoice.profile(bundleID: Self.firefox, id: "/ff/Profiles/a.Work")
        #expect(
            try plan(meet, browser: Self.firefox, profiles: Self.firefoxProfiles, choice: chosen)
                == .browserProfile(
                    try #require(URL(string: meetWithAccount)),
                    arguments: ["-profile", "/ff/Profiles/a.Work", "-new-tab", meetWithAccount]))
    }

    @Test func otherProvidersGetTheProfileButNotTheAccount() throws {
        let teams = "https://teams.microsoft.com/l/meetup-join/19%3ameeting%40thread.v2/0"
        #expect(try plan(URL(string: teams)) == chromiumPlan(teams, profile: "Profile 2"))
    }

    @Test func linksWithoutAnEventOpenAsBefore() throws {
        let room = try #require(URL(string: "https://meet.google.com/my-room"))
        #expect(try plan(room, email: nil) == .browser(room))
        #expect(
            try plan(room, email: nil, choice: .profile(bundleID: Self.chrome, id: "Default"))
                == chromiumPlan("https://meet.google.com/my-room", profile: "Default"))
    }

    @Test func nonWebLinksNeverBecomeLaunchArguments() throws {
        let file = try #require(URL(string: "file:///Applications/Calculator.app"))
        #expect(try plan(file, choice: .profile(bundleID: Self.chrome, id: "Default")) == .browser(file))
        let script = try #require(URL(string: "javascript:alert(1)"))
        #expect(try plan(script, choice: .profile(bundleID: Self.chrome, id: "Default")) == .browser(script))
    }

    @Test func unsafeProfileIdsNeverReachTheCommandLine() throws {
        let unsafe = [BrowserProfile(id: "--user-data-dir=/tmp", name: "x", email: Self.work)]
        #expect(try plan(meet, profiles: unsafe) == .browser(try #require(URL(string: meetWithAccount))))
        let relative = [BrowserProfile(id: "-safe-mode", name: "x", email: nil)]
        #expect(
            try plan(
                meet, browser: Self.firefox, profiles: relative,
                choice: .profile(bundleID: Self.firefox, id: "-safe-mode"))
                == .browser(try #require(URL(string: meetWithAccount))))
    }

    @Test func googleCalendarOnTheWebGetsAccountAndProfile() throws {
        let event = "https://calendar.google.com/calendar/event?eid=abc"
        #expect(
            try plan(URL(string: event))
                == chromiumPlan(event + "&authuser=juan@empresa.com", profile: "Profile 2"))
    }
}

struct AccountEmailTests {
    private let start = Fixture.at(10, 0)
    private let end = Fixture.at(10, 30)

    private func me(_ email: String?) -> Attendee {
        Attendee(name: "Juan", email: email, status: .accepted, kind: .person, isCurrentUser: true, isOrganizer: false)
    }

    @Test func theAccountNameComesFirst() {
        let event = Fixture.event(
            "Sync", start, end, sourceTitle: "juan@empresa.com", attendees: [me("juan.alias@empresa.com")])
        #expect(event.accountEmail == EmailAddress("juan@empresa.com"))
    }

    @Test func renamedAccountFallsBackToTheInvitedAddress() {
        let event = Fixture.event("Sync", start, end, sourceTitle: "Work", attendees: [me("juan@empresa.com")])
        #expect(event.accountEmail == EmailAddress("juan@empresa.com"))
    }

    @Test func otherAttendeesAreNeverUsed() {
        let colleague = Attendee(
            name: "Ana", email: "ana@empresa.com", status: .accepted, kind: .person, isCurrentUser: false, isOrganizer: true)
        let event = Fixture.event("Sync", start, end, sourceTitle: "Google", attendees: [colleague])
        #expect(event.accountEmail == nil)
    }

    @Test func aColleaguesCalendarTitleIsNeverUsed() {
        let event = Fixture.event("Sync", start, end, calendarID: "ana@empresa.com", sourceTitle: "Work")
        #expect(event.accountEmail == nil)
    }

    @Test func invalidAddressesAreSkipped() {
        let event = Fixture.event("Sync", start, end, sourceTitle: "Work", attendees: [me("not an address")])
        #expect(event.accountEmail == nil)
        let mailto = Fixture.event("Sync", start, end, sourceTitle: "", attendees: [me("mailto:juan@empresa.com")])
        #expect(mailto.accountEmail == EmailAddress("juan@empresa.com"))
    }
}
