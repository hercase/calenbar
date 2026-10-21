import Foundation

/// The user's say over which browser profile an account's meetings open in.
public enum ProfileChoice: Codable, Hashable, Sendable {
    /// The profile signed into the account, when the browser records it (Chromium); otherwise none.
    case automatic
    /// Never pick a profile: the browser uses whichever window is in front.
    case none
    /// This profile of this browser. Ignored for any other browser, and when the profile is gone.
    case profile(bundleID: String, id: String)
}

/// What to hand macOS to open a link.
public enum LaunchPlan: Equatable, Sendable {
    /// The service's own app (`zoommtg://`, `msteams://`).
    case native(URL)
    /// The meeting browser, as any link opens.
    case browser(URL)
    /// The meeting browser launched with these arguments, which name the profile and carry the URL.
    case browserProfile(URL, arguments: [String])
}

public struct LaunchContext: Sendable {
    /// The browser that will open the link, already resolved from "Default browser". Nil when unknown.
    public var browserBundleID: String?
    /// That browser's profiles.
    public var profiles: [BrowserProfile]
    /// The account the event belongs to; nil for links without an event (a personal room, a new meeting).
    public var accountEmail: EmailAddress?
    public var choice: ProfileChoice

    public init(
        browserBundleID: String?,
        profiles: [BrowserProfile] = [],
        accountEmail: EmailAddress? = nil,
        choice: ProfileChoice = .automatic
    ) {
        self.browserBundleID = browserBundleID
        self.profiles = profiles
        self.accountEmail = accountEmail
        self.choice = choice
    }
}

public enum MeetingLaunchPlanner {
    /// `nativeURL` only when the app is installed and preferred; it wins, since the app has its own login.
    public static func plan(webURL: URL, nativeURL: URL?, context: LaunchContext) -> LaunchPlan {
        if let nativeURL {
            return .native(nativeURL)
        }
        let url = context.accountEmail.map { GoogleAccountURL.url(webURL, signedInAs: $0) } ?? webURL
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
            let bundleID = context.browserBundleID,
            let family = BrowserFamily.of(bundleID: bundleID),
            let profile = profile(for: context, family: family),
            let arguments = arguments(engine: family.engine, profileID: profile.id, url: url)
        else { return .browser(url) }
        return .browserProfile(url, arguments: arguments)
    }

    /// The profile the context points at, or nil for "let the browser decide".
    public static func profile(for context: LaunchContext, family: BrowserFamily) -> BrowserProfile? {
        switch context.choice {
        case .none:
            return nil
        case .profile(let bundleID, let id) where bundleID.lowercased() == context.browserBundleID?.lowercased():
            if let chosen = context.profiles.first(where: { $0.id == id }) {
                return chosen
            }
            return automaticProfile(for: context, family: family)
        case .automatic, .profile:
            return automaticProfile(for: context, family: family)
        }
    }

    private static func automaticProfile(for context: LaunchContext, family: BrowserFamily) -> BrowserProfile? {
        guard family.engine == .chromium, let email = context.accountEmail else { return nil }
        return ProfileMatcher.profile(for: email, in: context.profiles)
    }

    /// Nil when the profile id isn't one this engine can be launched with safely. Chromium stops reading
    /// options at `--`, so nothing in the URL can act as one.
    static func arguments(engine: BrowserEngine, profileID: String, url: URL) -> [String]? {
        switch engine {
        case .chromium:
            guard ChromiumProfiles.isSafeDirectoryName(profileID) else { return nil }
            return ["--profile-directory=\(profileID)", "--", url.absoluteString]
        case .firefox:
            guard profileID.hasPrefix("/") else { return nil }
            return ["-profile", profileID, "-new-tab", url.absoluteString]
        }
    }
}

extension CalendarEvent {
    /// The account the event reached you through. The account's own name comes first (macOS names
    /// Google accounts after their address): an invitation may be addressed to an alias or a group,
    /// while the account is what the browser is signed into. The calendar's title is never used, since
    /// a colleague's calendar is named after their address, not yours.
    public var accountEmail: EmailAddress? {
        EmailAddress(calendarSourceTitle) ?? attendees.first(where: \.isCurrentUser)?.email.flatMap(EmailAddress.init)
    }
}
