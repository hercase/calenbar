import Foundation

public enum TitleFormatter {
    /// Thin spaces around the bullet keep the title compact.
    public static let separator = "\u{2009}•\u{2009}"

    public static func displayTitle(_ event: CalendarEvent) -> String {
        let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "(No title)") : trimmed
    }

    /// Stand-in for the title when the menu bar must not reveal it (screen sharing, recordings).
    public static func privateTitle(_ event: CalendarEvent) -> String {
        event.meetingLink == nil ? String(localized: "Event") : String(localized: "Meeting")
    }

    /// `now` during the first minute, `25m left` while ongoing, `in 1h 4m` before it starts.
    public static func suffix(for event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            if RelativeTime.minutesSince(event.start, now: now) == 0 {
                return String(localized: "now")
            }
            return String(localized: "\(RelativeTime.until(event.end, now: now)) left")
        }
        return String(localized: "in \(RelativeTime.until(event.start, now: now))")
    }

    public static func title(for event: CalendarEvent, now: Date) -> String {
        displayTitle(event) + separator + suffix(for: event, now: now)
    }

    /// Sentence-case variant for the panel: `Now`, `Ends in 12m`, `In 1h 2m`.
    public static func status(for event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            if RelativeTime.minutesSince(event.start, now: now) == 0 {
                return String(localized: "Now")
            }
            return String(localized: "Ends in \(RelativeTime.until(event.end, now: now))")
        }
        return String(localized: "In \(RelativeTime.until(event.start, now: now))")
    }

    /// A length of time, rounded up to whole minutes (never shows `0m`): `1m`, `45m`, `1h`, `1h 4m`.
    /// For "how long until / since" use `RelativeTime`, which reads minutes off the clock.
    public static func compactDuration(_ seconds: TimeInterval) -> String {
        compactMinutes(max(1, Int((seconds / 60).rounded(.up))))
    }

    /// `0m`, `45m`, `1h`, `1h 4m`.
    public static func compactMinutes(_ minutes: Int) -> String {
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
