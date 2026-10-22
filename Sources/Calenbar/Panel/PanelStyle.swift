import CalenbarCore
import SwiftUI

/// Shared spacing and building blocks so every panel section lines up the same way.
enum PanelStyle {
    /// Width of the panel.
    static let width: CGFloat = 340
    /// Left/right inset for every section, divider and row.
    static let inset: CGFloat = 14
    /// 4-pt scale.
    static let tight: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    /// Minimum clickable area for icon-only buttons.
    static let iconHitSize: CGFloat = 24
    static let rowCornerRadius: CGFloat = 6
}

/// Small grey title above a group ("Today", "World Clocks"), with an optional trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: PanelStyle.small) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            accessory
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// Divider aligned with the section insets.
struct PanelDivider: View {
    var body: some View {
        Divider().padding(.horizontal, PanelStyle.inset)
    }
}

/// Icon-only button with a comfortable hit area, tooltip and VoiceOver label.
struct IconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: PanelStyle.iconHitSize, height: PanelStyle.iconHitSize)
        }
        .buttonStyle(QuietButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

/// For buttons the panel draws itself. `.plain` and `.borderless` don't react to the pointer on macOS, so
/// a chip or an icon looked like a label until it was clicked. A wash appears on hover and deepens on
/// press, like toolbar buttons. `rest` is the wash a chip already shows before the pointer arrives.
struct QuietButtonStyle: ButtonStyle {
    var rest: Double = 0
    var cornerRadius: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        QuietButtonBody(configuration: configuration, rest: rest, cornerRadius: cornerRadius)
    }
}

/// Whether the pointer is over one control. A `@StateObject` rather than `@State`: the Command Line Tools
/// toolchain doesn't ship the SwiftUI macro plugin `@State` needs (see `PanelState`).
final class PointerHover: ObservableObject {
    @Published var isInside = false
}

extension View {
    /// The same hover wash for controls that can't take a button style, like a borderless `Menu`.
    func hoverWash(cornerRadius: CGFloat = 5) -> some View {
        modifier(HoverWash(cornerRadius: cornerRadius))
    }
}

private struct HoverWash: ViewModifier {
    let cornerRadius: CGFloat
    @StateObject private var hover = PointerHover()

    func body(content: Content) -> some View {
        content
            .background(
                Color.primary.opacity(hover.isInside ? 0.07 : 0),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .onHover { hover.isInside = $0 }
            .animation(.easeOut(duration: 0.12), value: hover.isInside)
    }
}

private struct QuietButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let rest: Double
    let cornerRadius: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @StateObject private var hover = PointerHover()

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(Color.primary.opacity(wash), in: shape)
            .contentShape(shape)
            .onHover { hover.isInside = $0 }
            .animation(.easeOut(duration: 0.12), value: hover.isInside)
    }

    private var wash: Double {
        guard isEnabled else { return rest }
        if configuration.isPressed { return rest + 0.14 }
        return hover.isInside ? rest + 0.07 : rest
    }
}

/// Calendar-colored bar beside an event. Hollow when the invitation still needs an answer
/// (the same convention as Calendar.app), so the state doesn't rely on a label alone.
struct CalendarColorBar: View {
    let colorHex: String
    let needsResponse: Bool

    var body: some View {
        let color = Color(hex: colorHex)
        if needsResponse {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(color, lineWidth: 1.5)
                .frame(width: 4)
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
        }
    }
}

/// "Your response: Yes" once an invitation is answered (changing it is the card's Open button).
struct RSVPStatusLine: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: PanelStyle.tight) {
            Text("Your response:")
                .foregroundStyle(.secondary)
            Text(label(event.myStatus))
        }
        .font(.callout)
    }

    private func label(_ status: ParticipationStatus) -> String {
        switch status {
        case .accepted: String(localized: "Yes")
        case .tentative: String(localized: "Maybe")
        case .declined: String(localized: "No")
        case .pending, .unknown: String(localized: "Not answered")
        }
    }
}
