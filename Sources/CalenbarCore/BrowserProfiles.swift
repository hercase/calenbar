import Foundation

/// How a browser is told which of its profiles to open a link in.
public enum BrowserEngine: Sendable, Equatable {
    /// `--profile-directory=<dir>`; `Local State` records the account signed into each profile.
    case chromium
    /// `-profile <path>`; `profiles.ini` lists profiles but not their accounts, so the user picks.
    case firefox
}

/// Browsers whose profiles Calenbar can target. Safari, Arc and the rest have no way to pick a
/// profile from outside, so they are absent and only get the account (`authuser`).
public struct BrowserFamily: Sendable, Equatable {
    public let engine: BrowserEngine
    /// Relative to `~/Library/Application Support`.
    public let dataDirectory: String

    /// Chrome, Edge and Brave channels keep separate profiles; every Firefox channel shares one `profiles.ini`.
    private static let known: [String: BrowserFamily] = [
        "com.google.chrome": .init(engine: .chromium, dataDirectory: "Google/Chrome"),
        "com.google.chrome.beta": .init(engine: .chromium, dataDirectory: "Google/Chrome Beta"),
        "com.google.chrome.dev": .init(engine: .chromium, dataDirectory: "Google/Chrome Dev"),
        "com.google.chrome.canary": .init(engine: .chromium, dataDirectory: "Google/Chrome Canary"),
        "com.brave.browser": .init(engine: .chromium, dataDirectory: "BraveSoftware/Brave-Browser"),
        "com.brave.browser.beta": .init(engine: .chromium, dataDirectory: "BraveSoftware/Brave-Browser-Beta"),
        "com.brave.browser.nightly": .init(engine: .chromium, dataDirectory: "BraveSoftware/Brave-Browser-Nightly"),
        "com.microsoft.edgemac": .init(engine: .chromium, dataDirectory: "Microsoft Edge"),
        "com.microsoft.edgemac.beta": .init(engine: .chromium, dataDirectory: "Microsoft Edge Beta"),
        "com.microsoft.edgemac.dev": .init(engine: .chromium, dataDirectory: "Microsoft Edge Dev"),
        "com.microsoft.edgemac.canary": .init(engine: .chromium, dataDirectory: "Microsoft Edge Canary"),
        "com.vivaldi.vivaldi": .init(engine: .chromium, dataDirectory: "Vivaldi"),
        "org.chromium.chromium": .init(engine: .chromium, dataDirectory: "Chromium"),
        "org.mozilla.firefox": .init(engine: .firefox, dataDirectory: "Firefox"),
        "org.mozilla.firefoxdeveloperedition": .init(engine: .firefox, dataDirectory: "Firefox"),
        "org.mozilla.nightly": .init(engine: .firefox, dataDirectory: "Firefox"),
    ]

    /// Bundle ids are case-insensitive to Launch Services, so they are here too.
    public static func of(bundleID: String) -> BrowserFamily? {
        known[bundleID.lowercased()]
    }

    /// The file listing this browser's profiles, relative to `dataDirectory`.
    public var profileListFile: String {
        switch engine {
        case .chromium: "Local State"
        case .firefox: "profiles.ini"
        }
    }
}

public struct BrowserProfile: Hashable, Sendable, Identifiable {
    /// What the browser is launched with: a Chromium profile directory name, or a Firefox profile's absolute path.
    public let id: String
    public let name: String
    /// The Google account signed into the profile, when the browser records it.
    public let email: EmailAddress?
    public let lastActive: Date?

    public init(id: String, name: String, email: EmailAddress?, lastActive: Date? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.lastActive = lastActive
    }
}

/// Reads the profile list out of a Chromium browser's `Local State`.
public enum ChromiumProfiles {
    /// `Local State` is a few hundred kilobytes; anything far bigger isn't one.
    public static let maxFileSize = 32 * 1_024 * 1_024

    /// Built-in profiles that never hold the user's accounts.
    private static let internalProfiles: Set<String> = ["Guest Profile", "System Profile"]

    /// Profiles in name order. Malformed entries are skipped; an unreadable file gives none.
    public static func parse(localState data: Data) -> [BrowserProfile] {
        guard data.count <= maxFileSize,
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let cache = (root["profile"] as? [String: Any])?["info_cache"] as? [String: Any]
        else { return [] }

        return cache.compactMap { directory, value -> BrowserProfile? in
            guard isSafeDirectoryName(directory), !internalProfiles.contains(directory),
                let info = value as? [String: Any],
                info["is_ephemeral"] as? Bool != true,
                info["is_omitted_from_profile_list"] as? Bool != true
            else { return nil }
            let name = [info["name"], info["gaia_name"]]
                .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            return BrowserProfile(
                id: directory,
                name: name ?? directory,
                email: (info["user_name"] as? String).flatMap(EmailAddress.init),
                lastActive: (info["active_time"] as? Double).map(Date.init(timeIntervalSince1970:))
            )
        }
        .sorted { ($0.name.localizedLowercase, $0.id) < ($1.name.localizedLowercase, $1.id) }
    }

    /// A single directory name that can't escape the data directory nor read as a command-line option.
    public static func isSafeDirectoryName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 255 && name != "." && name != ".."
            && !name.hasPrefix("-") && !name.contains("/") && !name.contains("\\")
            && !name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}

/// Reads Firefox's `profiles.ini`.
public enum FirefoxProfiles {
    public static let maxFileSize = 1_024 * 1_024

    /// Profiles in name order, each identified by its absolute path. Relative paths that climb out of
    /// `baseDirectory` are dropped.
    public static func parse(ini: String, baseDirectory: URL) -> [BrowserProfile] {
        guard ini.utf8.count <= maxFileSize else { return [] }
        let base = baseDirectory.standardizedFileURL.path

        var profiles: [BrowserProfile] = []
        for section in sections(of: ini) where isProfileSection(section.name) {
            guard let rawPath = section.values["path"], !rawPath.isEmpty else { continue }
            let isRelative = section.values["isrelative"] != "0"
            let path: String
            if isRelative {
                path = URL(fileURLWithPath: base).appendingPathComponent(rawPath).standardizedFileURL.path
                guard path.hasPrefix(base + "/") else { continue }
            } else {
                guard rawPath.hasPrefix("/") else { continue }
                path = URL(fileURLWithPath: rawPath).standardizedFileURL.path
            }
            guard !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                !profiles.contains(where: { $0.id == path })
            else { continue }
            let name = section.values["name"].flatMap { $0.isEmpty ? nil : $0 }
            profiles.append(BrowserProfile(id: path, name: name ?? (path as NSString).lastPathComponent, email: nil))
        }
        return profiles.sorted { ($0.name.localizedLowercase, $0.id) < ($1.name.localizedLowercase, $1.id) }
    }

    private struct Section {
        let name: String
        var values: [String: String] = [:]
    }

    /// `[Profile0]`, `[Profile12]`; not `[General]`, `[Install…]` or `[BackgroundTasksProfiles]`.
    private static func isProfileSection(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasPrefix("profile") else { return false }
        let number = lower.dropFirst("profile".count)
        return !number.isEmpty && number.allSatisfy(\.isASCII) && number.allSatisfy(\.isNumber)
    }

    /// Tolerates a BOM, CRLF line ends, comments and `=` inside values. Keys are lowercased; the first
    /// occurrence of a key in a section wins.
    private static func sections(of ini: String) -> [Section] {
        var result: [Section] = []
        let text = ini.hasPrefix("\u{FEFF}") ? String(ini.dropFirst()) : ini
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") {
                continue
            }
            if line.hasPrefix("["), line.hasSuffix("]") {
                result.append(Section(name: String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)))
                continue
            }
            guard let equals = line.firstIndex(of: "="), !result.isEmpty else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if result[result.count - 1].values[key] == nil {
                result[result.count - 1].values[key] = value
            }
        }
        return result
    }
}

public enum ProfileMatcher {
    /// The profile signed into this account. When several are (two copies of one account), the most
    /// recently used, then the first by id, so the answer never flips between runs.
    public static func profile(for email: EmailAddress, in profiles: [BrowserProfile]) -> BrowserProfile? {
        profiles
            .filter { $0.email == email }
            .min { lhs, rhs in
                let left = lhs.lastActive ?? .distantPast
                let right = rhs.lastActive ?? .distantPast
                return left != right ? left > right : lhs.id < rhs.id
            }
    }
}
