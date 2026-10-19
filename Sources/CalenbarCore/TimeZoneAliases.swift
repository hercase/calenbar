import Foundation

/// "ET", "PT", "CET", "UTC": the names teams actually say, mapped to the zone they mean.
public enum TimeZoneAliases {
    private static let table: [String: String] = [
        "et": "America/New_York", "est": "America/New_York", "edt": "America/New_York", "eastern": "America/New_York",
        "ct": "America/Chicago", "cst": "America/Chicago", "cdt": "America/Chicago", "central": "America/Chicago",
        "mt": "America/Denver", "mst": "America/Denver", "mdt": "America/Denver", "mountain": "America/Denver",
        "pt": "America/Los_Angeles", "pst": "America/Los_Angeles", "pdt": "America/Los_Angeles", "pacific": "America/Los_Angeles",
        "akt": "America/Anchorage", "hst": "Pacific/Honolulu",
        "gmt": "GMT", "utc": "GMT", "z": "GMT",
        "bst": "Europe/London", "wet": "Europe/Lisbon", "cet": "Europe/Berlin", "cest": "Europe/Berlin", "eet": "Europe/Athens",
        "ist": "Asia/Kolkata", "sgt": "Asia/Singapore", "hkt": "Asia/Hong_Kong", "jst": "Asia/Tokyo", "kst": "Asia/Seoul",
        "aest": "Australia/Sydney", "aedt": "Australia/Sydney", "awst": "Australia/Perth", "nzst": "Pacific/Auckland",
        "art": "America/Argentina/Buenos_Aires", "brt": "America/Sao_Paulo", "clt": "America/Santiago",
        "cot": "America/Bogota", "pet": "America/Lima", "cdmx": "America/Mexico_City",
    ]

    /// The zone an abbreviation stands for, or nil when the text isn't one. Foundation's own
    /// abbreviation list is the fallback for anything not in the table.
    public static func identifier(for query: String) -> String? {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if let known = table[key] {
            return known
        }
        return TimeZone.abbreviationDictionary[key.uppercased()]
    }
}
