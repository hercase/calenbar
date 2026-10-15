import AppKit
import CalenbarCore
import SwiftUI

/// Full-screen reminder when a meeting starts. Checked on every minute tick.
@MainActor
final class FullScreenAlertController {
    private static let window: TimeInterval = 5 * 60

    private let model: AppModel
    private var panel: AlertPanel?
    private var shownKeys: Set<String> = []
    private var snoozedUntil: [String: Date] = [:]

    init(model: AppModel) {
        self.model = model
        observeContinuously { [weak self] in self?.check() }
    }

    private func check() {
        let now = model.now
        let settings = model.settings
        let events = model.events(for: .alert)
        guard settings.alertEnabled, panel == nil else { return }

        let lead = TimeInterval(settings.alertLeadMinutes * 60)
        let due = events.first { event in
            guard !shownKeys.contains(event.key) else { return false }
            if settings.alertOnlyWithLink, event.meetingLink == nil {
                return false
            }
            if let until = snoozedUntil[event.key], now < until {
                return false
            }
            let fireAt = event.start.addingTimeInterval(-lead)
            return now >= fireAt && now < event.start.addingTimeInterval(Self.window)
        }
        if let due {
            show(due)
        }
    }

    private func show(_ event: CalendarEvent) {
        shownKeys.insert(event.key)
        guard let screen = NSScreen.main else { return }

        let panel = AlertPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let blur = NSVisualEffectView(frame: screen.frame)
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        let content = NSHostingView(
            rootView: AlertView(
                event: event,
                join: { [weak self] link in
                    MeetingOpener.open(link)
                    self?.dismiss()
                },
                snooze: { [weak self] in
                    self?.snoozedUntil[event.key] = Date().addingTimeInterval(60)
                    self?.shownKeys.remove(event.key)
                    self?.dismiss()
                },
                dismiss: { [weak self] in self?.dismiss() }
            ))
        content.frame = blur.bounds
        content.autoresizingMask = [.width, .height]
        blur.addSubview(content)
        panel.contentView = blur

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private final class AlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct AlertView: View {
    let event: CalendarEvent
    let join: (MeetingLink) -> Void
    let snooze: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(event.start > Date() ? String(localized: "Starting soon") : String(localized: "Starting now"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(TitleFormatter.displayTitle(event))
                .font(.system(size: 44, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            HStack(spacing: 8) {
                Circle().fill(Color(hex: event.calendarColorHex)).frame(width: 10, height: 10)
                Text(verbatim: "\(EventTimeText.range(event)) · \(event.calendarTitle)")
            }
            .font(.title3)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let link = event.meetingLink {
                    Button("Join \(link.provider.displayName)") { join(link) }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
                Button("Snooze 1 min", action: snooze)
                Button("Dismiss", action: dismiss)
                    .keyboardShortcut(.cancelAction)
            }
            .controlSize(.extraLarge)
            .padding(.top, 12)
        }
        .padding(60)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
