import Foundation

public enum TitleFormatter {
    /// Thin spaces around the bullet keep the title compact.
    public static let separator = "\u{2009}•\u{2009}"

    public static func displayTitle(_ event: CalendarEvent) -> String {
        let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "(No title)") : trimmed
    }

    /// `now` during the first minute, `25m left` while ongoing, `in 1h 4m` before it starts.
    public static func suffix(for event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            if now.timeIntervalSince(event.start) < 60 {
                return String(localized: "now")
            }
            return String(localized: "\(compactDuration(event.end.timeIntervalSince(now))) left")
        }
        return String(localized: "in \(compactDuration(event.start.timeIntervalSince(now)))")
    }

    public static func title(for event: CalendarEvent, now: Date) -> String {
        displayTitle(event) + separator + suffix(for: event, now: now)
    }

    /// Panel header: `Ends in 12m` or `Upcoming in 1h 2m`.
    public static func header(for event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            return String(localized: "Ends in \(compactDuration(event.end.timeIntervalSince(now)))")
        }
        return String(localized: "Upcoming in \(compactDuration(event.start.timeIntervalSince(now)))")
    }

    /// Rounds up to whole minutes (never shows `0m`): `1m`, `45m`, `1h`, `1h 4m`.
    public static func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }
}

public enum TitleWidthFitter {
    /// Shortens the event title with `…` until `title • suffix` fits `maxWidth`.
    /// The suffix is never cut: the countdown is the most important part.
    public static func fit(
        title: String,
        suffix: String,
        maxWidth: Double,
        measure: (String) -> Double
    ) -> String {
        let full = title + TitleFormatter.separator + suffix
        if measure(full) <= maxWidth {
            return full
        }

        var characters = Array(title)
        while !characters.isEmpty {
            characters.removeLast()
            let base = String(characters).trimmingCharacters(in: .whitespaces)
            guard !base.isEmpty else { break }
            let candidate = base + "…" + TitleFormatter.separator + suffix
            if measure(candidate) <= maxWidth {
                return candidate
            }
        }
        return suffix
    }
}
