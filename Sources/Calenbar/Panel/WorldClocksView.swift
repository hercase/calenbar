import SwiftUI

/// World clocks on one line: day/night icon, name and local time; offset in the tooltip.
struct InlineClocksView: View {
    let clocks: [WorldClock]
    let now: Date

    var body: some View {
        HStack(spacing: PanelStyle.medium) {
            ForEach(clocks.prefix(3)) { clock in
                HStack(spacing: 4) {
                    Image(systemName: Self.isDaytime(in: clock.timeZone, at: now) ? "sun.max.fill" : "moon.fill")
                        .font(.caption2)
                        .foregroundStyle(Self.isDaytime(in: clock.timeZone, at: now) ? Color.orange : Color.indigo)
                    Text(clock.name)
                        .foregroundStyle(.secondary)
                    Text(now.formatted(Self.timeStyle(in: clock.timeZone)))
                        .monospacedDigit()
                }
                .lineLimit(1)
                .help(
                    "\(clock.name): \(Self.offset(of: clock.timeZone, at: now)), \(Self.relativeDay(in: clock.timeZone, at: now))"
                )
            }
        }
        .font(.caption)
    }

    static func isDaytime(in zone: TimeZone, at date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = zone
        let hour = calendar.component(.hour, from: date)
        return (7..<19).contains(hour)
    }

    private static func timeStyle(in zone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return style
    }

    /// Difference from the local zone, e.g. `-1h`, `+5h 30m`, `Same time`.
    static func offset(of zone: TimeZone, at date: Date) -> String {
        let delta = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        guard delta != 0 else { return String(localized: "Same time") }
        let sign = delta > 0 ? "+" : "-"
        let hours = abs(delta) / 3_600
        let minutes = abs(delta) % 3_600 / 60
        return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h \(minutes)m"
    }

    static func relativeDay(in zone: TimeZone, at date: Date) -> String {
        var remote = Calendar.current
        remote.timeZone = zone
        let parts = remote.dateComponents([.year, .month, .day], from: date)
        let local = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let remoteDay = Calendar.current.date(from: parts), let localDay = Calendar.current.date(from: local) else {
            return String(localized: "Today")
        }
        let days = Calendar.current.dateComponents([.day], from: localDay, to: remoteDay).day ?? 0
        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        case -1: return String(localized: "Yesterday")
        default: return remoteDay.formatted(.dateTime.weekday(.abbreviated))
        }
    }
}
