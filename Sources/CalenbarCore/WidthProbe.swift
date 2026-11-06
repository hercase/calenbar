import Foundation

/// When to try a wider menu bar title again. macOS never says how much room the bar has left, only
/// that the item didn't fit (hidden, or pushed left of the notch). So the title shrinks when that
/// happens and, from time to time, tries one step wider: room comes back as soon as icons or app
/// menus are gone, and a bar that is still full is tried less and less often.
public struct WidthProbe: Sendable {
    /// Wait after the bar made the title shrink, or after the first try that didn't fit.
    public static let firstRetry: TimeInterval = 10 * 60
    /// Each try that doesn't fit doubles the wait, up to this.
    public static let longestRetry: TimeInterval = 4 * 60 * 60

    public private(set) var failures = 0
    /// nil: a wider title may be tried right away.
    public private(set) var retryAt: Date?

    public init() {}

    public func isDue(now: Date) -> Bool {
        retryAt.map { now >= $0 } ?? true
    }

    /// The wider title fit: keep climbing.
    public mutating func fit() {
        failures = 0
        retryAt = nil
    }

    /// The wider title didn't fit: wait longer before the next try.
    public mutating func didNotFit(now: Date) {
        failures += 1
        retryAt = now.addingTimeInterval(Self.delay(afterFailures: failures))
    }

    /// The bar filled up on its own: don't grow straight back into it.
    public mutating func shrank(now: Date) {
        let earliest = now.addingTimeInterval(Self.firstRetry)
        retryAt = max(retryAt ?? earliest, earliest)
    }

    static func delay(afterFailures failures: Int) -> TimeInterval {
        let doublings = Double(max(0, failures - 1))
        return min(longestRetry, firstRetry * pow(2, doublings))
    }

    /// One step wider than `current`, capped at `ceiling`; nil when there is nothing wider to try.
    /// A `current` of nil (not even the narrowest title fit) tries the narrowest again.
    public static func wider(than current: Double?, step: Double, narrowest: Double, ceiling: Double) -> Double? {
        guard let current else { return narrowest }
        guard current < ceiling else { return nil }
        return min(ceiling, current + step)
    }
}
