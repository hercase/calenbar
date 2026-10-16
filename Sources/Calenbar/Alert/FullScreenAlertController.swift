import AppKit
import CalenbarCore
import SwiftUI

/// Reminder when a meeting starts, as a full-screen takeover or a corner card. Checked on every minute tick.
@MainActor
final class FullScreenAlertController {
    private let model: AppModel
    private var panel: NSPanel?
    private var shownEvent: CalendarEvent?
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
        // Whatever is showing goes away by itself once its meeting is over.
        if let shownEvent, shownEvent.end <= now {
            dismiss()
        }
        guard settings.alertEnabled, panel == nil else { return }

        let lead = TimeInterval(settings.alertLeadMinutes * 60)
        let due = events.first { event in
            guard !shownKeys.contains(event.key) else { return false }
            if settings.alertOnlyWithLink, event.meetingLink == nil {
                return false
            }
            // Already joined from Calenbar: no need to take over the screen.
            if MeetingOpener.wasJoinedRecently(eventKey: event.key) {
                return false
            }
            return AlertTiming.isDue(event: event, now: now, lead: lead, snoozedUntil: snoozedUntil[event.key])
        }
        if let due {
            show(due)
        }
    }

    /// Settings' "Show Test Alert": the current style with a made-up meeting, so people can decide
    /// whether they want it. Its buttons only close it.
    func showPreview() {
        dismiss()
        let now = Date()
        let sample = CalendarEvent(
            id: "preview", externalID: "preview", title: String(localized: "This is how an alert looks"),
            start: now, end: now.addingTimeInterval(30 * 60), isAllDay: false, calendarID: "preview",
            calendarTitle: "Calenbar", calendarColorHex: "#4C4ED6", isDeclined: false, hasOtherAttendees: false,
            url: URL(string: "https://meet.google.com/abc-defg-hij"), location: nil, notes: nil)
        let close = AlertActions(
            join: { [weak self] _ in self?.dismiss() },
            snooze: { [weak self] _ in self?.dismiss() },
            dismiss: { [weak self] in self?.dismiss() }
        )
        present(sample, actions: close)
    }

    private func show(_ event: CalendarEvent) {
        shownKeys.insert(event.key)
        let actions = AlertActions(
            join: { [weak self] link in
                MeetingOpener.open(link, eventKey: event.key)
                self?.dismiss()
            },
            snooze: { [weak self] until in
                self?.snoozedUntil[event.key] = until
                self?.shownKeys.remove(event.key)
                self?.dismiss()
            },
            dismiss: { [weak self] in self?.dismiss() }
        )
        present(event, actions: actions)
    }

    private func present(_ event: CalendarEvent, actions: AlertActions) {
        guard let screen = Self.screen(for: model.settings.alertDisplayID) else { return }
        shownEvent = event
        switch model.settings.alertStyle {
        case .fullScreen: panel = showFullScreen(event, actions: actions, on: screen)
        case .card: panel = showCard(event, actions: actions, on: screen)
        }
    }

    private func showFullScreen(_ event: CalendarEvent, actions: AlertActions, on screen: NSScreen) -> NSPanel {
        let panel = KeyPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let blur = NSVisualEffectView(frame: screen.frame)
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        let content = NSHostingView(rootView: AlertView(model: model, event: event, actions: actions))
        content.frame = blur.bounds
        content.autoresizingMask = [.width, .height]
        blur.addSubview(content)
        panel.contentView = blur

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        return panel
    }

    /// In the chosen corner of the screen, inside the visible area (menu bar and Dock excluded), above
    /// everything, without taking focus from the current app.
    private func showCard(_ event: CalendarEvent, actions: AlertActions, on screen: NSScreen) -> NSPanel {
        let content = NSHostingView(rootView: AlertCardView(model: model, event: event, actions: actions))
        let size = content.fittingSize
        let margin: CGFloat = 12
        let area = screen.visibleFrame
        let corner = model.settings.alertCorner
        let x = corner == .topLeft || corner == .bottomLeft ? area.minX + margin : area.maxX - size.width - margin
        let y = corner == .topLeft || corner == .topRight ? area.maxY - size.height - margin : area.minY + margin
        let origin = NSPoint(x: x, y: y)
        // Can become key (so its buttons take the first click) without activating Calenbar.
        let panel = KeyPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        content.frame = NSRect(origin: .zero, size: size)
        panel.contentView = content
        panel.orderFrontRegardless()
        return panel
    }

    /// The chosen display if it is connected; otherwise the screen with the pointer, which is where
    /// the user is looking (not necessarily the one with the key window).
    static func screen(for displayID: UInt32?) -> NSScreen? {
        if let displayID, let chosen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            return chosen
        }
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
    }

    private func dismiss() {
        guard let panel else { return }
        self.panel = nil
        shownEvent = nil
        panel.orderOut(nil)
        // Called from a button inside the window: let the click finish before the window goes away.
        DispatchQueue.main.async { panel.close() }
    }
}

extension NSScreen {
    /// Stable id of the display (CoreGraphics `CGDirectDisplayID`), used to remember a chosen screen.
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// What the alert's buttons do; the same for both styles.
struct AlertActions {
    let join: (MeetingLink) -> Void
    /// Called with the moment the alert should come back.
    let snooze: (Date) -> Void
    let dismiss: () -> Void
}

struct AlertView: View {
    let model: AppModel
    let event: CalendarEvent
    let actions: AlertActions

    var body: some View {
        let now = model.now
        VStack(spacing: 18) {
            Text(Self.headline(event: event, now: now))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(TitleFormatter.displayTitle(event))
                // A full-screen takeover; fixed size on purpose, well above `.largeTitle`.
                .font(.system(size: 44, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: event.calendarColorHex)).frame(width: 10, height: 10)
                    Text(verbatim: "\(EventTimeText.range(event)) · \(event.calendarTitle)")
                }
                if let place {
                    Label(place, systemImage: event.rooms.isEmpty ? "mappin.and.ellipse" : "door.left.hand.open")
                        .lineLimit(1)
                }
                if let people {
                    Label(people, systemImage: "person.2")
                        .lineLimit(1)
                }
            }
            .font(.title3)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let link = event.meetingLink {
                    Button {
                        actions.join(link)
                    } label: {
                        HStack(spacing: 8) {
                            ProviderIconView(provider: link.provider, size: 18)
                            Text("Join \(link.provider.displayName)")
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
                SnoozeMenu(event: event, now: now, snooze: actions.snooze)
                    .fixedSize()
                Button("Dismiss", action: actions.dismiss)
                    .keyboardShortcut(.cancelAction)
            }
            .controlSize(.extraLarge)
            .padding(.top, 12)
        }
        .padding(60)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var place: String? { AlertFacts.place(event) }
    private var people: String? { AlertFacts.people(event) }

    static func headline(event: CalendarEvent, now: Date) -> String { AlertFacts.headline(event: event, now: now) }
}

/// Snooze choices shared by both alert styles.
struct SnoozeMenu: View {
    let event: CalendarEvent
    let now: Date
    let snooze: (Date) -> Void

    var body: some View {
        Menu("Snooze") {
            if event.start.timeIntervalSince(now) > 60 {
                Button("When it starts") { snooze(event.start) }
            }
            ForEach(AlertTiming.snoozeMinutes, id: \.self) { minutes in
                Button("\(minutes) min") { snooze(Date().addingTimeInterval(TimeInterval(minutes * 60))) }
            }
        }
    }
}

/// The lines both alert styles print about the meeting.
enum AlertFacts {
    /// Rooms first (they're what you walk to); otherwise the free-text location when it says something.
    static func place(_ event: CalendarEvent) -> String? {
        event.rooms.isEmpty ? event.displayLocation : event.rooms.joined(separator: ", ")
    }

    /// "Organized by Ana · 6 guests · 4 accepted"; nothing for an event with no other guests.
    static func people(_ event: CalendarEvent) -> String? {
        let others = event.people.filter { !$0.isCurrentUser }
        guard !others.isEmpty else { return nil }
        let accepted = event.people.filter { $0.status == .accepted }.count
        let counts = String(localized: "\(event.people.count) guests · \(accepted) accepted")
        if let organizer = event.organizer, !organizer.isCurrentUser {
            return String(localized: "Organized by \(organizer.displayName)") + " · " + counts
        }
        return counts
    }

    /// Live: "Starting in 2m", then "Starting now" for the first minute, then "Started 3m ago".
    static func headline(event: CalendarEvent, now: Date) -> String {
        let sinceStart = now.timeIntervalSince(event.start)
        if sinceStart < 0 {
            return String(localized: "Starting in \(TitleFormatter.compactDuration(-sinceStart))")
        }
        if sinceStart < 60 {
            return String(localized: "Starting now")
        }
        return String(localized: "Started \(TitleFormatter.compactDuration(sinceStart)) ago")
    }
}
