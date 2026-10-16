import AppKit
import CalenbarCore

/// Opens meeting and event links, honoring the user's browser and native-app preferences.
@MainActor
enum MeetingOpener {
    struct Browser: Identifiable, Hashable {
        let id: String
        let name: String
    }

    /// Kept in sync with `AppSettings` by the app delegate.
    static var browserBundleID = ""
    static var preferNativeApps = true

    /// Occurrences the user joined from Calenbar, by event key, so the full-screen alert stays quiet
    /// for them. Per occurrence, not per link: a meeting moved to a later time is a new key and alerts again.
    private static var joined: [String: Date] = [:]
    private static let joinMemory: TimeInterval = 90 * 60

    /// True when this occurrence was joined from Calenbar recently (the user is presumably in that call).
    static func wasJoinedRecently(eventKey: String, now: Date = Date()) -> Bool {
        guard let joinedAt = joined[eventKey] else { return false }
        return now.timeIntervalSince(joinedAt) < joinMemory
    }

    /// Zoom/Teams links go to their app when installed (and preferred); everything else to the browser.
    /// Pass the event's key so the alert for that occurrence can be skipped.
    static func open(_ link: MeetingLink, eventKey: String? = nil) {
        if let eventKey {
            joined[eventKey] = Date()
        }
        if preferNativeApps, let native = link.nativeURL, NSWorkspace.shared.urlForApplication(toOpen: native) != nil {
            NSWorkspace.shared.open(native)
        } else {
            openInBrowser(link.webURL)
        }
    }

    static func openInBrowser(_ url: URL) {
        guard !browserBundleID.isEmpty,
            let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleID)
        else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    static func copy(_ link: MeetingLink) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.webURL.absoluteString, forType: .string)
    }

    /// Apps registered with macOS to open web links (the same list System Settings shows).
    static func installedBrowsers() -> [Browser] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: probe)
            .compactMap { url -> Browser? in
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
                let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
                return Browser(id: id, name: name)
            }
            .reduce(into: [Browser]()) { unique, browser in
                if !unique.contains(where: { $0.id == browser.id }) {
                    unique.append(browser)
                }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
