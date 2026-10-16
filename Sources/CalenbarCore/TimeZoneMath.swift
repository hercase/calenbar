import Foundation

/// Pure time-zone arithmetic for world clocks and "meeting time over there" lines.
/// Views turn the numbers into localized text.
public enum TimeZoneMath {
    /// Seconds `zone` is ahead of `local` at `date` (negative when behind). DST-aware on both sides.
    public static func offset(of zone: TimeZone, from local: TimeZone = .current, at date: Date) -> Int {
        zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)
    }

    /// `+5h 30m`, `-1h`; nil when both zones show the same time.
    public static func offsetText(of zone: TimeZone, from local: TimeZone = .current, at date: Date) -> String? {
        let delta = offset(of: zone, from: local, at: date)
        guard delta != 0 else { return nil }
        let sign = delta > 0 ? "+" : "-"
        let hours = abs(delta) / 3_600
        let minutes = abs(delta) % 3_600 / 60
        return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h \(minutes)m"
    }

    /// Calendar days between the local date and the date in `zone` at the same instant:
    /// 1 when it's already tomorrow there, -1 when still yesterday, 0 otherwise.
    public static func dayDifference(
        in zone: TimeZone,
        from local: TimeZone = .current,
        at date: Date,
        calendar: Calendar = .current
    ) -> Int {
        var remote = calendar
        remote.timeZone = zone
        var here = calendar
        here.timeZone = local
        let there = remote.dateComponents([.year, .month, .day], from: date)
        let home = here.dateComponents([.year, .month, .day], from: date)
        // Compare the two civil dates on a neutral calendar so DST and offsets can't skew the count.
        var neutral = Calendar(identifier: calendar.identifier)
        neutral.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let thereDay = neutral.date(from: there), let homeDay = neutral.date(from: home) else { return 0 }
        return neutral.dateComponents([.day], from: homeDay, to: thereDay).day ?? 0
    }

    /// 7:00–18:59 local to the zone counts as day (sun icon); the rest is night (moon icon).
    public static func isDaytime(in zone: TimeZone, at date: Date, calendar: Calendar = .current) -> Bool {
        var remote = calendar
        remote.timeZone = zone
        return (7..<19).contains(remote.component(.hour, from: date))
    }
}
