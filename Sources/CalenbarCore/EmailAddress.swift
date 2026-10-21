import Foundation

/// An e-mail address read from an untrusted place (a calendar account name, an invitation, a browser's
/// profile file), accepted only in the plain form real accounts use. Anything else is nil rather than
/// guessed at: these addresses end up in URLs and pick which account a meeting opens with.
public struct EmailAddress: Hashable, Sendable, CustomStringConvertible {
    /// Trimmed, with the domain lowercased: what goes into a URL.
    public let value: String
    /// For comparing only: lowercased, with Google's two consumer domains folded together. Dots and
    /// `+tags` stay, since Workspace domains don't ignore them the way gmail.com does.
    public let canonical: String

    private static let maxLength = 254
    private static let maxLocalLength = 64
    private static let localCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._+-'")
    private static let domainCharacters = Set("abcdefghijklmnopqrstuvwxyz0123456789-")

    /// Accepts a bare address or EventKit's `mailto:` form; nil for anything that isn't a plain ASCII address.
    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("mailto:") {
            text = String(text.dropFirst("mailto:".count))
        }
        guard text.utf8.count <= Self.maxLength else { return nil }
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let local = String(parts[0])
        let domain = parts[1].lowercased()
        guard Self.isValidLocal(local), Self.isValidDomain(domain) else { return nil }

        value = "\(local)@\(domain)"
        canonical = "\(local.lowercased())@\(domain == "googlemail.com" ? "gmail.com" : domain)"
    }

    public var description: String { value }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.canonical == rhs.canonical }

    public func hash(into hasher: inout Hasher) { hasher.combine(canonical) }

    private static func isValidLocal(_ local: String) -> Bool {
        !local.isEmpty && local.utf8.count <= maxLocalLength
            && local.allSatisfy(localCharacters.contains)
            && !local.hasPrefix(".") && !local.hasSuffix(".") && !local.contains("..")
    }

    private static func isValidDomain(_ domain: String) -> Bool {
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        return labels.allSatisfy { label in
            !label.isEmpty && label.count <= 63 && label.allSatisfy(domainCharacters.contains)
                && !label.hasPrefix("-") && !label.hasSuffix("-")
        }
    }
}
