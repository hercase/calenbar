import SwiftUI

/// A small pill to preview one menu bar flash: a color dot and its name, a stop square while it runs.
struct FlashTestButton<Title: View>: View {
    let color: Color
    let isRunning: Bool
    let action: () -> Void
    @ViewBuilder let title: Title

    var body: some View {
        Button(action: action) {
            Label {
                title
            } icon: {
                if isRunning {
                    Image(systemName: "stop.fill").font(.system(size: 8))
                } else {
                    Circle().fill(color).frame(width: 8, height: 8)
                }
            }
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
        .tint(isRunning ? color : nil)
        .help(isRunning ? Text("Stop the preview") : Text("Preview this flash in the menu bar"))
        .accessibilityValue(isRunning ? Text("Running") : Text(""))
    }
}

/// A miniature of the menu bar item that flashes in step with the real one, so the preview is visible
/// right here and shows the exact colors and text contrast.
struct FlashMockBar: View {
    let flash: FlashPreview?
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lit: FlashPreview? { isOn ? flash : nil }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar")
            Text(verbatim: "Team sync • in 4m").lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(textColor)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(RoundedRectangle(cornerRadius: 4).fill(lit.map { Color(nsColor: $0.nsColor) } ?? .clear))
        .padding(.horizontal, 6)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.08)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: lit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Menu bar preview"))
    }

    private var textColor: Color {
        switch lit {
        case .yellow: .black
        case .red: .white
        case nil: .primary
        }
    }
}
