import Foundation

/// A time zone the user's meetings keep coming from, offered as a world clock.
public struct ClockSuggestion: Equatable, Hashable, Identifiable, Sendable {
    public let timeZoneID: String
    /// Distinct events (a recurring series counts once) that point at this zone.
    public let eventCount: Int
    public let lastEvent: Date

    public var id: String { timeZoneID }

    public init(timeZoneID: String, eventCount: Int, lastEvent: Date) {
        self.timeZoneID = timeZoneID
        self.eventCount = eventCount
        self.lastEvent = lastEvent
    }

    /// "America/Los_Angeles" reads "Los Angeles".
    public var cityName: String {
        (timeZoneID.split(separator: "/").last.map(String.init) ?? timeZoneID).replacingOccurrences(of: "_", with: " ")
    }
}

/// A suggestion the user turned down, with how strong it was at the time.
public struct ClockDismissal: Codable, Equatable, Sendable {
    public var date: Date
    public var eventCount: Int

    public init(date: Date, eventCount: Int) {
        self.date = date
        self.eventCount = eventCount
    }
}

/// Finds the time zones the user's meetings point at that they have no clock for. Two signals, both
/// read from events already on the Mac: the zone the event was created in, and "11am PT" in its
/// title, notes or location.
public enum ClockSuggestions {
    public static let minimumEvents = 2
    public static let maximumSuggestions = 3
    /// How long a "no thanks" holds, unless the zone gets much busier.
    public static let dismissalLifetime: TimeInterval = 90 * 86_400
    public static let lookBackDays = 30
    public static let lookAheadDays = 60

    public static func suggest(
        events: [CalendarEvent],
        now: Date,
        system: TimeZone = .current,
        existing: Set<String>,
        dismissed: [String: ClockDismissal] = [:],
        limit: Int = maximumSuggestions
    ) -> [ClockSuggestion] {
        var series: [String: [String: Date]] = [:]  // zone -> event series -> latest start
        for event in events where !event.isAllDay {
            for zone in zones(of: event) {
                let latest = series[zone, default: [:]][event.externalID] ?? .distantPast
                series[zone, default: [:]][event.externalID] = max(latest, event.start)
            }
        }
        let known = existing.compactMap(TimeZone.init(identifier:)) + [system]
        let candidates = series.compactMap { zone, occurrences -> ClockSuggestion? in
            guard occurrences.count >= minimumEvents, let last = occurrences.values.max(),
                !isCovered(zone, by: known, at: now), !isDismissed(zone, count: occurrences.count, in: dismissed, at: now)
            else { return nil }
            return ClockSuggestion(timeZoneID: zone, eventCount: occurrences.count, lastEvent: last)
        }
        return
            candidates
            .sorted { ($0.eventCount, $0.lastEvent, $1.timeZoneID) > ($1.eventCount, $1.lastEvent, $0.timeZoneID) }
            .prefix(limit)
            .map { $0 }
    }

    private static func zones(of event: CalendarEvent) -> Set<String> {
        var found = Set<String>()
        if let id = event.timeZoneID, TimeZone(identifier: id) != nil {
            found.insert(id)
        }
        for text in [event.title, event.location, event.notes] {
            if let text { found.formUnion(TimeZoneMentions.zones(in: text)) }
        }
        return found
    }

    /// The same wall clock as a zone the user already has (or their own): New York and Toronto are one
    /// clock for a meeting, so suggesting the second would only be noise.
    private static func isCovered(_ identifier: String, by known: [TimeZone], at date: Date) -> Bool {
        guard let zone = TimeZone(identifier: identifier) else { return true }
        let probes = [date, date.addingTimeInterval(180 * 86_400)]
        return known.contains { other in
            other.identifier == identifier
                || probes.allSatisfy { zone.secondsFromGMT(for: $0) == other.secondsFromGMT(for: $0) }
        }
    }

    private static func isDismissed(_ zone: String, count: Int, in dismissed: [String: ClockDismissal], at now: Date) -> Bool {
        guard let entry = dismissed[zone] else { return false }
        if now.timeIntervalSince(entry.date) > dismissalLifetime { return false }
        return count < entry.eventCount * 3
    }
}

/// "11am PT", "10:30 CET", "3 PM EST": a clock time followed by a zone name. A bare "PT" or "ET" in a
/// sentence is too often something else, so a time has to come first.
public enum TimeZoneMentions {
    private static let names: Set<String> = [
        "et", "est", "edt", "ct", "cst", "cdt", "mt", "mst", "mdt", "pt", "pst", "pdt",
        "cet", "cest", "eet", "eest", "bst", "wet", "west", "sgt", "hkt", "jst", "kst",
        "aest", "aedt", "awst", "nzst", "nzdt", "brt", "clt", "cot", "pet", "art",
    ]

    public static func zones(in text: String) -> Set<String> {
        let words =
            text
            .split(whereSeparator: { $0.isWhitespace || "-–—/,;()[]".contains($0) })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        var found = Set<String>()
        for (index, word) in words.enumerated() where index > 0 && names.contains(word.lowercased()) {
            guard let hasMeridiem = timeBefore(words, index) else { continue }
            // "pt" in lowercase is a word (points, part); only "PT", or a time that says am/pm, is a zone.
            guard word == word.uppercased() || hasMeridiem else { continue }
            if let zone = TimeZoneAliases.identifier(for: word) { found.insert(zone) }
        }
        return found
    }

    /// nil when no clock time precedes the word; otherwise whether that time carries am/pm.
    private static func timeBefore(_ words: [String], _ index: Int) -> Bool? {
        let previous = words[index - 1].lowercased()
        if isMeridiem(previous), index >= 2, isClockNumber(words[index - 2]) { return true }
        if let number = splitMeridiem(previous), isClockNumber(number) { return true }
        if isClockNumber(previous), previous.contains(":") { return false }
        return nil
    }

    private static func isMeridiem(_ word: String) -> Bool {
        ["am", "pm", "a.m.", "p.m."].contains(word)
    }

    /// "11am" -> "11"
    private static func splitMeridiem(_ word: String) -> String? {
        for suffix in ["a.m.", "p.m.", "am", "pm"] where word.hasSuffix(suffix) {
            return String(word.dropLast(suffix.count))
        }
        return nil
    }

    private static func isClockNumber(_ word: String) -> Bool {
        let parts = word.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return false }
        return parts[0].count <= 2 && (parts.count == 1 || parts[1].count == 2)
    }
}
