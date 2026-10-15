import Foundation

/// A dotted version like `0.2.0` (a leading `v`, as in git tags, is accepted).
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public let parts: [Int]

    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let parts = digits.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    public var description: String {
        parts.map(String.init).joined(separator: ".")
    }

    public func isNewer(than other: AppVersion) -> Bool {
        other < self
    }

    /// Missing components count as zero, so `1.0` == `1.0.0`.
    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
