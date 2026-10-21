import CalenbarCore
import SwiftUI

/// One time for the gap, then a chip for what that time becomes. The arrows move the start and the
/// length row stretches it; Focus, Lunch and Meeting all use whatever the time says.
struct FreeTimeActions: View {
    let model: AppModel
    let state: PanelState
    let slot: FreeTime.Slot

    var body: some View {
        let placement = state.placement(for: slot, defaultLength: defaultLength)
        VStack(spacing: PanelStyle.tight) {
            timeRow(placement)
            if placement.choices.count > 1 {
                EqualActionRow(spacing: PanelStyle.tight) {
                    ForEach(placement.choices, id: \.self) { choice in
                        lengthButton(choice, placement: placement)
                    }
                }
            }
            EqualActionRow(spacing: PanelStyle.tight) {
                chip("moon", title: String(localized: "Focus"), help: busyHelp) {
                    model.blockFocus(from: placement.interval.start, to: placement.interval.end)
                }
                chip("fork.knife", title: String(localized: "Lunch"), help: busyHelp) {
                    model.blockLunch(from: placement.interval.start, to: placement.interval.end)
                }
                chip(
                    "calendar.badge.plus", title: String(localized: "Meeting…"),
                    help: String(localized: "New meeting, \(Self.range(placement.interval))")
                ) {
                    model.draftMeeting(from: placement.interval.start, to: placement.interval.end)
                }
            }
        }
    }

    private func timeRow(_ placement: FreeTime.Placement) -> some View {
        HStack(spacing: PanelStyle.tight) {
            if placement.canMoveEarlier || placement.canMoveLater {
                shiftButton("chevron.left", enabled: placement.canMoveEarlier, label: String(localized: "Earlier")) {
                    state.shiftBlock(slot, forward: false, defaultLength: defaultLength)
                }
            }
            Text(Self.range(placement.interval))
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if placement.canMoveEarlier || placement.canMoveLater {
                shiftButton("chevron.right", enabled: placement.canMoveLater, label: String(localized: "Later")) {
                    state.shiftBlock(slot, forward: true, defaultLength: defaultLength)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func lengthButton(_ choice: FreeTime.BlockLength, placement: FreeTime.Placement) -> some View {
        let selected = Self.isChosen(choice, placement: placement)
        return Button {
            state.chooseLength(slot, choice, defaultLength: defaultLength)
        } label: {
            Text(Self.lengthTitle(choice, room: slot.end.timeIntervalSince(placement.interval.start)))
                .font(.callout.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 4)
                .padding(.horizontal, PanelStyle.tight)
                .background(
                    Color.primary.opacity(selected ? 0.14 : 0.05),
                    in: RoundedRectangle(cornerRadius: PanelStyle.rowCornerRadius)
                )
        }
        .buttonStyle(GapActionStyle())
        .accessibilityLabel(Self.lengthLabel(choice, end: slot.end))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chip(_ systemImage: String, title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PanelStyle.tight) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, PanelStyle.tight)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: PanelStyle.rowCornerRadius)
            )
        }
        .buttonStyle(GapActionStyle())
        .help(help)
        .accessibilityLabel(help)
    }

    private func shiftButton(_ systemImage: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: PanelStyle.iconHitSize, height: PanelStyle.iconHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .help(label)
        .accessibilityLabel(label)
    }

    private var defaultLength: TimeInterval {
        TimeInterval(model.settings.lunchMinutes * 60)
    }

    private var busyHelp: String {
        let name =
            model.calendar.blockDestination(preferredID: model.settings.blockCalendarID)?.title
            ?? String(localized: "Default calendar")
        return String(localized: "Busy on \(name). Other people can't book you, and Calenbar doesn't alert.")
    }

    /// "4:00 PM" and "4:30 PM" read as "4:00–4:30 PM". A 24-hour clock, or a range that crosses
    /// noon, keeps both times.
    private static func range(_ interval: DateInterval) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened)
        let start = interval.start.formatted(style)
        let end = interval.end.formatted(style)
        guard let suffix = sharedMeridiem(start, end) else { return "\(start)–\(end)" }
        let trimmed = String(start.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        return "\(trimmed)–\(end)"
    }

    private static func sharedMeridiem(_ start: String, _ end: String) -> String? {
        let markers = ["AM", "PM", "a.m.", "p.m.", "a. m.", "p. m."]
        for marker in markers {
            guard start.hasSuffix(marker), end.hasSuffix(marker) else { continue }
            let startBody = start.dropLast(marker.count)
            let endBody = end.dropLast(marker.count)
            guard let startSpace = startBody.last, startSpace.isWhitespace,
                let endSpace = endBody.last, endSpace.isWhitespace
            else { continue }
            return String(start.suffix(marker.count + 1))
        }
        return nil
    }

    private static func isChosen(_ choice: FreeTime.BlockLength, placement: FreeTime.Placement) -> Bool {
        switch (choice, placement.length) {
        case (.untilEnd, .untilEnd): true
        case (.fixed(let chosen), .fixed(let current)): abs(chosen - current) < 1
        default: false
        }
    }

    /// The clock range already says when. This row only says how long, in the same compact voice as the gap.
    private static func lengthTitle(_ choice: FreeTime.BlockLength, room: TimeInterval) -> String {
        switch choice {
        case .fixed(let value): TitleFormatter.compactDuration(value)
        case .untilEnd: TitleFormatter.compactDuration(room)
        }
    }

    private static func lengthLabel(_ choice: FreeTime.BlockLength, end: Date) -> String {
        switch choice {
        case .fixed(let value) where abs(value - 30 * 60) < 1: String(localized: "30 minutes")
        case .fixed(let value) where abs(value - 60 * 60) < 1: String(localized: "1 hour")
        case .fixed(let value) where abs(value - 2 * 60 * 60) < 1: String(localized: "2 hours")
        case .fixed(let value): TitleFormatter.compactDuration(value)
        case .untilEnd:
            String(localized: "Until \(end.formatted(Date.FormatStyle(date: .omitted, time: .shortened)))")
        }
    }
}

/// Focus, Lunch and Meeting are one set of choices, so every chip gets the same width and height.
struct EqualActionRow: Layout {
    var spacing: CGFloat = PanelStyle.tight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        guard !subviews.isEmpty else { return .zero }
        let itemWidth = itemWidth(total: width, count: subviews.count)
        let height =
            subviews.map {
                $0.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil)).height
            }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard !subviews.isEmpty else { return }
        let itemWidth = itemWidth(total: bounds.width, count: subviews.count)
        let itemProposal = ProposedViewSize(width: itemWidth, height: bounds.height)
        var x = bounds.minX
        for subview in subviews {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: itemProposal)
            x += itemWidth + spacing
        }
    }

    private func itemWidth(total: CGFloat, count: Int) -> CGFloat {
        let gaps = spacing * CGFloat(max(0, count - 1))
        return max(0, (total - gaps) / CGFloat(count))
    }
}

/// Dims on press without recoloring the title.
private struct GapActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}
