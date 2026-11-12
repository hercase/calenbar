import CalenbarCore
import SwiftUI

/// World clocks section of the panel: one row per clock (at most three), like a small clock list.
struct WorldClocksView: View {
    let clocks: [WorldClock]
    let now: Date

    var body: some View {
        VStack(spacing: PanelStyle.small) {
            ForEach(clocks.prefix(AppSettings.maxWorldClocks)) { clock in
                let isDay = TimeZoneMath.isDaytime(in: clock.timeZone, at: now)
                HStack(spacing: PanelStyle.small) {
                    Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
                        .font(.caption)
                        .foregroundStyle(isDay ? Color.orange : Color.indigo)
                        .frame(width: 16)
                    Text(clock.name)
                        .lineLimit(1)
                    Text(Self.offsetText(of: clock.timeZone, at: now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: PanelStyle.small)
                    if let day = Self.dayNote(in: clock.timeZone, at: now) {
                        Text(day)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(now.formatted(Self.timeStyle(in: clock.timeZone)))
                        .monospacedDigit()
                }
                .font(.callout)
            }
        }
        .padding(.horizontal, PanelStyle.inset)
        .padding(.vertical, PanelStyle.small + 2)
    }

    /// "Tomorrow" / "Yesterday" when the clock is on another calendar day; nil on the same day.
    static func dayNote(in zone: TimeZone, at date: Date) -> String? {
        switch TimeZoneMath.dayDifference(in: zone, at: date) {
        case 1: String(localized: "Tomorrow")
        case -1: String(localized: "Yesterday")
        default: nil
        }
    }

    /// Difference from the local zone: `-1h`, `+5h 30m`, or `Same time`.
    static func offsetText(of zone: TimeZone, at date: Date) -> String {
        TimeZoneMath.offsetText(of: zone, at: date) ?? String(localized: "Same time")
    }

    static func timeStyle(in zone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return style
    }
}

/// One quiet line under a short list of clocks: the meetings point at zones the user has no clock for.
/// It only opens Settings, where the suggestions live; nothing is added from the panel.
struct ClockNudgeView: View {
    let names: [String]
    let open: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: PanelStyle.small) {
            Text("Meetings in \(ListFormatter.localizedString(byJoining: names))")
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer(minLength: PanelStyle.small)
            Button("Add clocks", action: open)
                .buttonStyle(.link)
            IconButton(systemImage: "xmark", label: String(localized: "Dismiss"), action: dismiss)
        }
        .font(.caption)
        .padding(.horizontal, PanelStyle.inset)
        .padding(.bottom, PanelStyle.small)
    }
}
