import AppKit
import CalenbarCore

/// Opens meeting and event links, honoring the user's browser and native-app preferences, and opening
/// each event's links with the account (and browser profile) it belongs to.
@MainActor
enum MeetingOpener {
    struct Browser: Identifiable, Hashable {
        let id: String
        let name: String
    }

    /// Kept in sync with `AppSettings` by the app delegate.
    static var browserBundleID = ""
    static var preferNativeApps = true
    static var profileChoices: [String: ProfileChoice] = [:]

    /// Occurrences the user joined from Calenbar, by event key, so the full-screen alert stays quiet
    /// for them. Per occurrence, not per link: a meeting moved to a later time is a new key and alerts again.
    private static var joined: [String: Date] = [:]
    private static let joinMemory: TimeInterval = 90 * 60

    /// Joining earlier than this before the start is opening the waiting room, not being in the call.
    private static let joinedNearStart: TimeInterval = 2 * 60

    /// A double click, or the shortcut pressed twice, opens the call once.
    private static var lastLaunch: (plan: LaunchPlan, at: Date)?
    private static let repeatWindow: TimeInterval = 1.5

    /// True when this occurrence was joined from Calenbar recently and close to its start (the user is
    /// presumably in that call). An early join still gets the alert: people open the link, then drift off.
    static func wasJoinedRecently(eventKey: String, start: Date, now: Date = Date()) -> Bool {
        guard let joinedAt = joined[eventKey], joinedAt >= start.addingTimeInterval(-joinedNearStart) else {
            return false
        }
        return now.timeIntervalSince(joinedAt) < joinMemory
    }

    /// Zoom/Teams links go to their app when installed (and preferred); everything else to the browser,
    /// with the event's account. `eventKey` alone (no event at hand) still keeps that occurrence's alert quiet.
    static func open(_ link: MeetingLink, eventKey: String? = nil, event: CalendarEvent? = nil) {
        if let key = eventKey ?? event?.key {
            joined[key] = Date()
        }
        let native = link.nativeURL.flatMap { url in
            preferNativeApps && NSWorkspace.shared.urlForApplication(toOpen: url) != nil ? url : nil
        }
        let browser = meetingBrowserApp()
        let context = launchContext(for: event, browser: browser)
        launch(MeetingLaunchPlanner.plan(webURL: link.webURL, nativeURL: native, context: context), browser: browser)
    }

    /// In the meeting browser; with the event's account when there is one (Google Calendar on the web).
    static func openInBrowser(_ url: URL, event: CalendarEvent? = nil) {
        let browser = meetingBrowserApp()
        let context = launchContext(for: event, browser: browser)
        launch(MeetingLaunchPlanner.plan(webURL: url, nativeURL: nil, context: context), browser: browser)
    }

    /// The link as the invitation has it: an `authuser` would hand your address to whoever it's pasted to.
    static func copy(_ link: MeetingLink) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.webURL.absoluteString, forType: .string)
    }

    /// The browser meeting links open in: the chosen one while it's installed, otherwise the system default.
    static func meetingBrowser() -> Browser? {
        guard let app = meetingBrowserApp(), let bundle = Bundle(url: app.url) else { return nil }
        return Browser(id: app.bundleID, name: displayName(of: bundle.bundleURL))
    }

    private struct BrowserApp {
        let bundleID: String
        let url: URL
        /// Picked in Settings, as opposed to the system default.
        let isChosen: Bool
    }

    /// Resolved on every click: the default browser or the installed apps can change while Calenbar runs.
    private static func meetingBrowserApp() -> BrowserApp? {
        if !browserBundleID.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleID) {
            return BrowserApp(bundleID: browserBundleID, url: url, isChosen: true)
        }
        guard let probe = URL(string: "https://example.com"),
            let url = NSWorkspace.shared.urlForApplication(toOpen: probe),
            let bundleID = Bundle(url: url)?.bundleIdentifier
        else { return nil }
        return BrowserApp(bundleID: bundleID, url: url, isChosen: false)
    }

    private static func launchContext(for event: CalendarEvent?, browser: BrowserApp?) -> LaunchContext {
        guard let event else { return LaunchContext(browserBundleID: browser?.bundleID) }
        var profiles: [BrowserProfile] = []
        if let browser, case .profiles(let list) = BrowserProfileReader.listing(for: browser.bundleID) {
            profiles = list
        }
        return LaunchContext(
            browserBundleID: browser?.bundleID,
            profiles: profiles,
            accountEmail: event.accountEmail,
            choice: profileChoices[event.calendarSourceID] ?? .automatic
        )
    }

    private static func launch(_ plan: LaunchPlan, browser: BrowserApp?) {
        let now = Date()
        if let last = lastLaunch, last.plan == plan, now.timeIntervalSince(last.at) < repeatWindow {
            return
        }
        lastLaunch = (plan, now)

        switch plan {
        case .native(let url):
            NSWorkspace.shared.open(url)
        case .browser(let url):
            openPlain(url, browser: browser)
        case .browserProfile(let url, let arguments):
            guard let browser else {
                openPlain(url, browser: nil)
                return
            }
            // Through Launch Services, not a child process: the browser must be the one macOS asks for
            // the camera and microphone. A new instance hands the arguments to the running browser and quits.
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = arguments
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: browser.url, configuration: configuration) { _, error in
                guard error != nil else { return }
                Task { @MainActor in openPlain(url, browser: browser) }
            }
        }
    }

    private static func openPlain(_ url: URL, browser: BrowserApp?) {
        guard let browser, browser.isChosen else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: browser.url, configuration: NSWorkspace.OpenConfiguration())
    }

    private static var browserCache: [Browser]?

    /// Apps registered with macOS to open web links (the same list System Settings shows). Asked of
    /// Launch Services once per run: the Settings form re-evaluates often, the list doesn't change.
    static func installedBrowsers() -> [Browser] {
        if let browserCache {
            return browserCache
        }
        guard let probe = URL(string: "https://example.com") else { return [] }
        let browsers = NSWorkspace.shared.urlsForApplications(toOpen: probe)
            .compactMap { url -> Browser? in
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
                return Browser(id: id, name: displayName(of: url))
            }
            .reduce(into: [Browser]()) { unique, browser in
                if !unique.contains(where: { $0.id == browser.id }) {
                    unique.append(browser)
                }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        browserCache = browsers
        return browsers
    }

    private static func displayName(of appURL: URL) -> String {
        FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: "")
    }
}
