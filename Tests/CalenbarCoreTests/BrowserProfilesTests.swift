import Foundation
import Testing

@testable import CalenbarCore

struct ChromiumProfilesTests {
    /// Shape of a real Chrome `Local State`, trimmed and anonymized.
    private let localState = """
        {
          "browser": { "last_redirect_origin": "" },
          "profile": {
            "last_used": "Profile 2",
            "info_cache": {
              "Default": {
                "name": "Personal", "user_name": "Juan@Gmail.com", "gaia_name": "Juan Pérez",
                "active_time": 1760000000.5, "is_using_default_name": false
              },
              "Profile 2": { "name": "DEPT 🚀", "user_name": "juan.perez@deptagency.com", "active_time": 1761000000 },
              "Profile 3": { "name": "", "gaia_name": "Cliente", "user_name": "" },
              "Profile 4": { "name": "Sin cuenta" },
              "Guest Profile": { "name": "Guest" },
              "System Profile": { "name": "System" },
              "Profile 5": { "name": "Temp", "is_ephemeral": true },
              "Profile 6": { "name": "Hidden", "is_omitted_from_profile_list": true }
            }
          }
        }
        """

    private func parse(_ json: String) -> [BrowserProfile] {
        ChromiumProfiles.parse(localState: Data(json.utf8))
    }

    @Test func readsProfilesWithTheirAccounts() {
        let profiles = parse(localState)
        #expect(profiles.map(\.id) == ["Profile 3", "Profile 2", "Default", "Profile 4"])
        let personal = profiles.first { $0.id == "Default" }
        #expect(personal?.name == "Personal")
        #expect(personal?.email == EmailAddress("juan@gmail.com"))
        #expect(personal?.lastActive == Date(timeIntervalSince1970: 1760000000.5))
        #expect(profiles.first { $0.id == "Profile 2" }?.name == "DEPT 🚀")
    }

    @Test func fallsBackToTheGoogleNameThenTheDirectory() {
        let profiles = parse(localState)
        #expect(profiles.first { $0.id == "Profile 3" }?.name == "Cliente")
        #expect(profiles.first { $0.id == "Profile 3" }?.email == nil)
        #expect(parse(#"{"profile":{"info_cache":{"Profile 9":{}}}}"#).first?.name == "Profile 9")
    }

    @Test func skipsBuiltInHiddenAndEphemeralProfiles() {
        let ids = Set(parse(localState).map(\.id))
        #expect(ids.isDisjoint(with: ["Guest Profile", "System Profile", "Profile 5", "Profile 6"]))
    }

    @Test(arguments: [
        "", "not json", "[]", "{}", #"{"profile":[]}"#, #"{"profile":{}}"#, #"{"profile":{"info_cache":[]}}"#,
        #"{"profile":{"info_cache":"x"}}"#, "\u{FEFF}{",
    ])
    func malformedFilesGiveNoProfiles(_ json: String) {
        #expect(parse(json).isEmpty)
    }

    @Test func wrongTypesSkipTheEntryOrTheField() {
        let profiles = parse(
            #"{"profile":{"info_cache":{"Default":"x","Profile 1":{"name":7,"user_name":["a"],"active_time":"soon"}}}}"#)
        #expect(profiles.map(\.id) == ["Profile 1"])
        #expect(profiles.first?.email == nil)
        #expect(profiles.first?.lastActive == nil)
    }

    @Test func invalidAccountAddressesAreIgnored() {
        let profiles = parse(#"{"profile":{"info_cache":{"Default":{"user_name":"juan@empresa.com&authuser=9"}}}}"#)
        #expect(profiles.first?.email == nil)
    }

    @Test(arguments: [
        "../Library", "..", ".", "-flag", "--user-data-dir=/tmp", "a/b", "a\\b", "Pro\nfile", "",
        String(repeating: "x", count: 256),
    ])
    func unsafeDirectoryNamesAreDropped(_ directory: String) throws {
        let json = try JSONSerialization.data(withJSONObject: ["profile": ["info_cache": [directory: ["name": "x"]]]])
        #expect(ChromiumProfiles.parse(localState: json).isEmpty)
        #expect(!ChromiumProfiles.isSafeDirectoryName(directory))
    }

    @Test func customDirectoryNamesAreKept() {
        #expect(ChromiumProfiles.isSafeDirectoryName("Default"))
        #expect(ChromiumProfiles.isSafeDirectoryName("Profile 12"))
        #expect(ChromiumProfiles.isSafeDirectoryName("Trabajo"))
    }

    @Test func oversizedFilesAreNotParsed() {
        var data = Data(localState.utf8)
        data.append(Data(repeating: 0x20, count: ChromiumProfiles.maxFileSize))
        #expect(ChromiumProfiles.parse(localState: data).isEmpty)
    }
}

struct FirefoxProfilesTests {
    private let base = URL(fileURLWithPath: "/Users/juan/Library/Application Support/Firefox")

    private let ini = """
        [General]
        StartWithLastProfile=1
        Version=2

        [Profile1]
        Name=Trabajo
        IsRelative=1
        Path=Profiles/abcd1234.Trabajo

        [Profile0]
        Name=default-release
        IsRelative=1
        Path=Profiles/xyz98765.default-release
        Default=1

        [Install6C6A4B1E]
        Default=Profiles/xyz98765.default-release
        Locked=1
        """

    @Test func readsProfilesAsAbsolutePaths() {
        let profiles = FirefoxProfiles.parse(ini: ini, baseDirectory: base)
        #expect(profiles.map(\.name) == ["default-release", "Trabajo"])
        #expect(profiles.last?.id == base.path + "/Profiles/abcd1234.Trabajo")
        #expect(profiles.allSatisfy { $0.email == nil })
    }

    @Test func toleratesBOMCRLFCommentsAndSpacing() {
        let messy =
            "\u{FEFF}; comment\r\n# another\r\n[Profile0]\r\n  Name = Personal  \r\n"
            + "IsRelative=1\r\nPath=Profiles/p.Personal\r\n"
        let profiles = FirefoxProfiles.parse(ini: messy, baseDirectory: base)
        #expect(profiles.map(\.name) == ["Personal"])
    }

    @Test func keepsEqualsSignsInValuesAndFirstKeyWins() {
        let text = "[Profile0]\nName=a=b\nName=ignored\nPath=Profiles/p\n"
        #expect(FirefoxProfiles.parse(ini: text, baseDirectory: base).first?.name == "a=b")
    }

    @Test func absolutePathsAndMissingNames() {
        let text = "[Profile0]\nIsRelative=0\nPath=/Volumes/Data/ff/work\n[Profile1]\nIsRelative=0\nPath=relative/oops\n"
        let profiles = FirefoxProfiles.parse(ini: text, baseDirectory: base)
        #expect(profiles.map(\.id) == ["/Volumes/Data/ff/work"])
        #expect(profiles.first?.name == "work")
    }

    @Test func relativePathsThatEscapeTheFolderAreDropped() {
        let text = "[Profile0]\nName=x\nPath=../../../../etc\n[Profile1]\nName=y\nPath=Profiles/../../Firefox-evil\n"
        #expect(FirefoxProfiles.parse(ini: text, baseDirectory: base).isEmpty)
    }

    @Test func duplicateNamesStayDistinctByPath() {
        let text =
            "[Profile0]\nName=Work\nPath=Profiles/a\n[Profile1]\nName=Work\nPath=Profiles/b\n"
            + "[Profile2]\nName=Again\nPath=Profiles/a\n"
        let profiles = FirefoxProfiles.parse(ini: text, baseDirectory: base)
        #expect(profiles.count == 2)
        #expect(Set(profiles.map(\.id)) == [base.path + "/Profiles/a", base.path + "/Profiles/b"])
    }

    @Test func ignoresNonProfileSectionsAndEntriesWithoutPath() {
        let text =
            "[BackgroundTasksProfiles]\nPath=x\n[ProfileX]\nPath=Profiles/x\n[Profile0]\nName=NoPath\n"
            + "[Profile٣]\nPath=Profiles/arabic\n"
        #expect(FirefoxProfiles.parse(ini: text, baseDirectory: base).isEmpty)
    }

    @Test func keysBeforeAnySectionAreIgnored() {
        #expect(FirefoxProfiles.parse(ini: "Path=Profiles/x\n", baseDirectory: base).isEmpty)
    }
}

struct ProfileMatcherTests {
    private let juan = EmailAddress("juan@empresa.com")

    @Test func matchesTheSignedInAccountIgnoringCase() throws {
        let profiles = [
            BrowserProfile(id: "Default", name: "Personal", email: EmailAddress("juan@gmail.com")),
            BrowserProfile(id: "Profile 1", name: "Work", email: EmailAddress("JUAN@Empresa.com")),
        ]
        #expect(ProfileMatcher.profile(for: try #require(juan), in: profiles)?.id == "Profile 1")
    }

    @Test func noMatchIsNil() throws {
        let profiles = [BrowserProfile(id: "Default", name: "Personal", email: nil)]
        #expect(ProfileMatcher.profile(for: try #require(juan), in: profiles) == nil)
    }

    @Test func mostRecentlyUsedWinsThenTheId() throws {
        let email = try #require(juan)
        let older = BrowserProfile(id: "Profile 1", name: "A", email: email, lastActive: Date(timeIntervalSince1970: 10))
        let newer = BrowserProfile(id: "Profile 9", name: "B", email: email, lastActive: Date(timeIntervalSince1970: 20))
        let undated = BrowserProfile(id: "Profile 0", name: "C", email: email)
        #expect(ProfileMatcher.profile(for: email, in: [older, newer, undated])?.id == "Profile 9")
        let tieA = BrowserProfile(id: "Profile 2", name: "A", email: email)
        let tieB = BrowserProfile(id: "Profile 1", name: "B", email: email)
        #expect(ProfileMatcher.profile(for: email, in: [tieA, tieB])?.id == "Profile 1")
        #expect(ProfileMatcher.profile(for: email, in: [tieB, tieA])?.id == "Profile 1")
    }
}

struct BrowserFamilyTests {
    @Test func knowsChromiumAndFirefoxBrowsersCaseInsensitively() {
        #expect(BrowserFamily.of(bundleID: "com.google.Chrome")?.engine == .chromium)
        #expect(BrowserFamily.of(bundleID: "COM.GOOGLE.CHROME")?.dataDirectory == "Google/Chrome")
        #expect(BrowserFamily.of(bundleID: "com.brave.Browser")?.dataDirectory == "BraveSoftware/Brave-Browser")
        #expect(BrowserFamily.of(bundleID: "com.microsoft.edgemac")?.profileListFile == "Local State")
        #expect(BrowserFamily.of(bundleID: "org.mozilla.firefox")?.profileListFile == "profiles.ini")
    }

    @Test(arguments: ["com.apple.Safari", "company.thebrowser.Browser", "company.thebrowser.dia", "", "com.google.Chrome.evil"])
    func othersCannotPickAProfile(_ bundleID: String) {
        #expect(BrowserFamily.of(bundleID: bundleID) == nil)
    }
}
