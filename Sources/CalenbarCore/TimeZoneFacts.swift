import Foundation

/// What a world clock is worth saying besides the time: the zone's short name, its UTC offset, and
/// whether its clocks are about to change.
public enum TimeZoneFacts {
    /// "PDT", "CET", "GMT": the abbreviation in force at `date`. Always the English one, which is what
    /// teams write in chat; `TimeZone.abbreviation(for:)` would follow the Mac's language.
    public static func abbreviation(of zone: TimeZone, at date: Date) -> String? {
        let style: TimeZone.NameStyle = zone.isDaylightSavingTime(for: date) ? .shortDaylightSaving : .shortStandard
        if let name = zone.localizedName(for: style, locale: Locale(identifier: "en_US")), !name.hasPrefix("GMT") {
            return name
        }
        // ICU only names a few zones; Foundation's abbreviation table knows CET/CEST, BST, JST, AEDT…
        // Each entry names one city (CEST → Paris), so match on offset and daylight state within the
        // same region, preferring the zone itself.
        let offset = zone.secondsFromGMT(for: date)
        let isDaylight = zone.isDaylightSavingTime(for: date)
        let region = zone.identifier.split(separator: "/").first.map(String.init) ?? ""
        let candidates = TimeZone.abbreviationDictionary.filter { _, identifier in
            guard let other = TimeZone(identifier: identifier) else { return false }
            return other.secondsFromGMT(for: date) == offset && other.isDaylightSavingTime(for: date) == isDaylight
                && identifier.hasPrefix(region + "/")
        }
        func rank(_ entry: (key: String, value: String)) -> (Int, String) {
            (entry.value == zone.identifier ? 0 : 1, entry.key)
        }
        return candidates.min { rank($0) < rank($1) }?.key
    }

    /// "UTC−7", "UTC+5:30", "UTC".
    public static func utcOffsetText(of zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        guard seconds != 0 else { return "UTC" }
        let sign = seconds < 0 ? "\u{2212}" : "+"
        let hours = abs(seconds) / 3_600
        let minutes = abs(seconds) % 3_600 / 60
        return minutes == 0 ? "UTC\(sign)\(hours)" : String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    /// The next daylight-saving switch in that zone when it falls within `days`, with the change in
    /// hours relative to now (+1 when clocks go forward). Nil when none is coming.
    public static func upcomingClockChange(
        in zone: TimeZone, at date: Date, within days: Int = 31
    ) -> (date: Date, hourShift: Double)? {
        guard let next = zone.nextDaylightSavingTimeTransition(after: date),
            next.timeIntervalSince(date) <= Double(days) * 86_400
        else { return nil }
        let after = next.addingTimeInterval(60)
        let shift = Double(zone.secondsFromGMT(for: after) - zone.secondsFromGMT(for: date)) / 3_600
        return (next, shift)
    }
}
