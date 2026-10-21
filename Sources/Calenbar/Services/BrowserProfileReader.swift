import CalenbarCore
import Foundation

/// The profiles of the browsers that can open a link in a chosen one, read from the browser's own
/// files. Addresses found there stay in memory; nothing is written back or persisted.
@MainActor
enum BrowserProfileReader {
    enum Listing: Equatable {
        /// The browser has no way to be told which profile to use.
        case unsupported
        /// It does, but its profile list is missing or couldn't be read.
        case unreadable
        case profiles([BrowserProfile])
    }

    /// Re-read only when the file changes: every Join and every Settings render asks.
    private static var cache: [String: (modified: Date, listing: Listing)] = [:]

    static func listing(for bundleID: String) -> Listing {
        guard let family = BrowserFamily.of(bundleID: bundleID) else { return .unsupported }
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return .unreadable
        }
        let directory = support.appendingPathComponent(family.dataDirectory, isDirectory: true)
        let file = directory.appendingPathComponent(family.profileListFile)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
            attributes[.type] as? FileAttributeType == .typeRegular,
            let size = attributes[.size] as? Int,
            let modified = attributes[.modificationDate] as? Date
        else { return .unreadable }

        if let cached = cache[file.path], cached.modified == modified {
            return cached.listing
        }
        let listing = read(file, size: size, family: family, directory: directory)
        cache[file.path] = (modified, listing)
        return listing
    }

    private static func read(_ file: URL, size: Int, family: BrowserFamily, directory: URL) -> Listing {
        let profiles: [BrowserProfile]
        switch family.engine {
        case .chromium:
            guard size <= ChromiumProfiles.maxFileSize, let data = try? Data(contentsOf: file) else { return .unreadable }
            profiles = ChromiumProfiles.parse(localState: data)
        case .firefox:
            guard size <= FirefoxProfiles.maxFileSize, let data = try? Data(contentsOf: file),
                let ini = String(bytes: data, encoding: .utf8)
            else { return .unreadable }
            profiles = FirefoxProfiles.parse(ini: ini, baseDirectory: directory)
        }
        // Every install has at least one profile; none means the file isn't what we expect.
        return profiles.isEmpty ? .unreadable : .profiles(profiles)
    }
}
