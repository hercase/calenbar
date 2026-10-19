import Foundation

public enum MeetingProvider: String, CaseIterable, Sendable {
    case zoom
    case googleMeet
    case teams
    case webex
    case faceTime
    case slack
    case jitsi
    case around
    case whereby
    case pexip
    case chime
    case gather

    public var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Google Meet"
        case .teams: "Microsoft Teams"
        case .webex: "Webex"
        case .faceTime: "FaceTime"
        case .slack: "Slack Huddle"
        case .jitsi: "Jitsi Meet"
        case .around: "Around"
        case .whereby: "Whereby"
        case .pexip: "Pexip"
        case .chime: "Amazon Chime"
        case .gather: "Gather"
        }
    }

    /// Services with an instant-meeting page, in the order the "New Meeting" menu lists them.
    public static let instantMeetingProviders: [MeetingProvider] = [.googleMeet, .zoom, .teams]

    /// Where a brand-new call starts, for `instantMeetingProviders`.
    public var newMeetingURL: URL? {
        switch self {
        case .googleMeet: URL(string: "https://meet.new")
        case .zoom: URL(string: "https://zoom.us/start/videomeeting")
        case .teams: URL(string: "https://teams.microsoft.com/l/meeting/new")
        default: nil
        }
    }
}

public struct MeetingLink: Equatable, Hashable, Sendable {
    public let provider: MeetingProvider
    public let webURL: URL
    /// App-specific URL (e.g. `zoommtg://`) that skips the browser hop when the app is installed.
    public let nativeURL: URL?
}

public enum MeetingLinkDetector {
    private struct Rule {
        let provider: MeetingProvider
        /// Host must equal this domain or be a subdomain of it.
        let domain: String
        /// Optional path prefix required to count as a meeting (e.g. Slack's huddle links).
        let pathPrefix: String?
    }

    // Video-call services whose links get a Join button.
    private static let rules: [Rule] = [
        Rule(provider: .zoom, domain: "zoom.us", pathPrefix: nil),
        Rule(provider: .zoom, domain: "zoomgov.com", pathPrefix: nil),
        Rule(provider: .zoom, domain: "zoom.com", pathPrefix: nil),
        Rule(provider: .googleMeet, domain: "meet.google.com", pathPrefix: nil),
        Rule(provider: .teams, domain: "teams.microsoft.com", pathPrefix: nil),
        Rule(provider: .teams, domain: "teams.live.com", pathPrefix: nil),
        Rule(provider: .webex, domain: "webex.com", pathPrefix: nil),
        Rule(provider: .faceTime, domain: "facetime.apple.com", pathPrefix: nil),
        Rule(provider: .slack, domain: "app.slack.com", pathPrefix: "/huddle"),
        Rule(provider: .jitsi, domain: "meet.jit.si", pathPrefix: nil),
        Rule(provider: .around, domain: "around.co", pathPrefix: nil),
        Rule(provider: .whereby, domain: "whereby.com", pathPrefix: nil),
        Rule(provider: .pexip, domain: "pexip.me", pathPrefix: nil),
        Rule(provider: .chime, domain: "chime.aws", pathPrefix: nil),
        Rule(provider: .gather, domain: "app.gather.town", pathPrefix: nil),
    ]

    /// Searches the event URL, then location, then notes; returns the first link that belongs to a
    /// known meeting provider. Generic links (docs, maps) are ignored.
    public static func detect(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        // Cheapest source first; the notes (often kilobytes of invitation HTML) only when needed.
        if let url, let link = meetingLink(for: url) {
            return link
        }
        for text in [location, notes] {
            if let link = links(in: text).lazy.compactMap(meetingLink(for:)).first {
                return link
            }
        }
        return nil
    }

    /// Built once: creating a data detector is the expensive part of a scan.
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private static func links(in text: String?) -> [URL] {
        guard let text, !text.isEmpty, let detector = linkDetector else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match in
            // Bare words like "zoom.us" are detected as links too; require an explicit scheme.
            guard let swiftRange = Range(match.range, in: text), text[swiftRange].contains("://") else {
                return nil
            }
            return match.url
        }
    }

    private static func meetingLink(for url: URL) -> MeetingLink? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
            let host = url.host?.lowercased()
        else { return nil }

        let rule = rules.first { rule in
            let hostMatches = host == rule.domain || host.hasSuffix("." + rule.domain)
            let pathMatches = rule.pathPrefix.map { url.path.hasPrefix($0) } ?? true
            return hostMatches && pathMatches
        }
        guard let rule else { return nil }

        return MeetingLink(provider: rule.provider, webURL: url, nativeURL: nativeURL(for: url, provider: rule.provider))
    }

    private static func nativeURL(for url: URL, provider: MeetingProvider) -> URL? {
        switch provider {
        case .zoom:
            return zoomNativeURL(for: url)
        case .teams:
            guard url.path.hasPrefix("/l/meetup-join"),
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { return nil }
            components.scheme = "msteams"
            return components.url
        default:
            return nil
        }
    }

    /// `https://host/j/123?pwd=x` → `zoommtg://host/join?confno=123&pwd=x`
    private static func zoomNativeURL(for url: URL) -> URL? {
        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "j"), index + 1 < parts.count,
            let host = url.host,
            let original = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        var components = URLComponents()
        components.scheme = "zoommtg"
        components.host = host
        components.path = "/join"
        components.queryItems =
            [URLQueryItem(name: "confno", value: parts[index + 1])]
            + (original.queryItems ?? [])
        return components.url
    }
}
