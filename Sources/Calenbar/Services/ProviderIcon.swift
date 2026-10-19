import AppKit
import CalenbarCore
import SwiftUI

/// Official icon for a meeting service: the installed app's own icon (what Finder shows), or a logo
/// bundled with Calenbar for web-only services like Google Meet. Nil means "use the tinted camera".
@MainActor
enum ProviderIcon {
    private static var cache: [MeetingProvider: NSImage?] = [:]

    private static let appBundleIDs: [MeetingProvider: [String]] = [
        .zoom: ["us.zoom.xos"],
        .teams: ["com.microsoft.teams2", "com.microsoft.teams"],
        .slack: ["com.tinyspeck.slackmacgap"],
        .faceTime: ["com.apple.FaceTime"],
        .webex: ["com.cisco.webexmeetingsapp", "com.webex.meetingmanager"],
    ]

    static func image(for provider: MeetingProvider) -> NSImage? {
        if let cached = cache[provider] {
            return cached
        }
        let image = installedAppIcon(for: provider) ?? bundledLogo(for: provider)
        cache[provider] = image
        return image
    }

    private static func installedAppIcon(for provider: MeetingProvider) -> NSImage? {
        for bundleID in appBundleIDs[provider] ?? [] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return nil
    }

    private static func bundledLogo(for provider: MeetingProvider) -> NSImage? {
        guard let url = Bundle.main.url(forResource: provider.rawValue, withExtension: "png", subdirectory: "ProviderIcons")
        else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

/// The logo on a small white tile, for prominent buttons: the button takes the user's accent colour,
/// and a full-colour logo straight on it can clash (Meet's green and blue on a blue button). Same
/// device as "Sign in with…" buttons.
struct ProviderChipView: View {
    let provider: MeetingProvider
    var size: CGFloat = 16

    var body: some View {
        ProviderIconView(provider: provider, size: size)
            .padding(3)
            .background(Color.white, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// The service's official icon at a given size, falling back to a camera in the service's color.
struct ProviderIconView: View {
    let provider: MeetingProvider
    var size: CGFloat = 16

    var body: some View {
        if let image = ProviderIcon.image(for: provider) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "video.fill")
                .foregroundStyle(provider.tint)
                .frame(width: size, height: size)
        }
    }
}
