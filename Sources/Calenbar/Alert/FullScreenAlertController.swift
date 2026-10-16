import AppKit
import CalenbarCore
import SwiftUI

/// Reminder when a meeting starts, as a full-screen takeover or corner cards. Checked on every minute tick.
@MainActor
final class FullScreenAlertController {
    private struct Shown {
        let event: CalendarEvent
        let panel: NSPanel
        let isCard: Bool
    }

    /// Cards stack from the chosen corner; more than this and they'd march across the screen.
    private static let maxCards = 3
    private static let margin: CGFloat = 24
    private static let gap: CGFloat = 8

    private let model: AppModel
    /// What is on screen, by event key. One takeover at most; up to `maxCards` cards.
    private var shown: [String: Shown] = [:]
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
        for entry in shown.values where entry.event.end <= now {
            dismiss(entry.event.key)
        }
        guard settings.alertEnabled else { return }

        let lead = TimeInterval(settings.alertLeadMinutes * 60)
        let due = events.filter { event in
            guard !shownKeys.contains(event.key) else { return false }
            if settings.alertOnlyWithLink, event.meetingLink == nil {
                return false
            }
            // Already joined from Calenbar: no need to interrupt.
            if MeetingOpener.wasJoinedRecently(eventKey: event.key) {
                return false
            }
            return AlertTiming.isDue(event: event, now: now, lead: lead, snoozedUntil: snoozedUntil[event.key])
        }
        switch settings.alertStyle {
        case .fullScreen:
            if shown.isEmpty, let first = due.first {
                show(first)
            }
        case .card:
            // Overlapping meetings each get a card, stacked, oldest start nearest the corner.
            for event in due.prefix(max(0, Self.maxCards - shown.count)) {
                show(event)
            }
        }
    }

    /// Settings' "Show Test Alert": the current style with a made-up meeting, so people can decide
    /// whether they want it. Its buttons only close it.
    func showPreview() {
        for key in shown.keys {
            dismiss(key)
        }
        let now = Date()
        let sample = CalendarEvent(
            id: "preview", externalID: "preview", title: String(localized: "This is how an alert looks"),
            start: now, end: now.addingTimeInterval(30 * 60), isAllDay: false, calendarID: "preview",
            calendarTitle: "Calenbar", calendarColorHex: "#4C4ED6", isDeclined: false, hasOtherAttendees: false,
            url: URL(string: "https://meet.google.com/abc-defg-hij"), location: nil, notes: nil)
        let close = AlertActions(
            join: { [weak self] _ in self?.dismiss(sample.key) },
            snooze: { [weak self] _ in self?.dismiss(sample.key) },
            dismiss: { [weak self] in self?.dismiss(sample.key) }
        )
        present(sample, actions: close)
    }

    private func show(_ event: CalendarEvent) {
        shownKeys.insert(event.key)
        let actions = AlertActions(
            join: { [weak self] link in
                MeetingOpener.open(link, eventKey: event.key)
                self?.dismiss(event.key)
            },
            snooze: { [weak self] until in
                self?.snoozedUntil[event.key] = until
                self?.shownKeys.remove(event.key)
                self?.dismiss(event.key)
            },
            dismiss: { [weak self] in self?.dismiss(event.key) }
        )
        present(event, actions: actions)
    }

    private func present(_ event: CalendarEvent, actions: AlertActions) {
        guard let screen = Self.screen(for: model.settings.alertDisplayID) else { return }
        switch model.settings.alertStyle {
        case .fullScreen:
            shown[event.key] = Shown(event: event, panel: showFullScreen(event, actions: actions, on: screen), isCard: false)
        case .card:
            shown[event.key] = Shown(event: event, panel: makeCard(event, actions: actions), isCard: true)
            layoutCards(on: screen, entering: event.key)
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

    /// A card above everything that doesn't take focus from the current app; `layoutCards` places it.
    private func makeCard(_ event: CalendarEvent, actions: AlertActions) -> NSPanel {
        let content = NSHostingView(rootView: AlertCardView(model: model, event: event, actions: actions))
        let size = content.fittingSize
        // Can become key (so its buttons take the first click) without activating Calenbar.
        let panel = KeyPanel(
            contentRect: NSRect(origin: .zero, size: size),
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
        content.frame = NSRect(origin: .zero, size: size)
        panel.contentView = content
        return panel
    }

    /// Stacks the cards from the chosen corner, inside the visible area (menu bar and Dock excluded):
    /// bottom corners grow upwards, top corners downwards. A new card slides in from the side edge;
    /// the others glide to their new slot. No motion when the system asks for less of it.
    private func layoutCards(on screen: NSScreen, entering newKey: String? = nil) {
        let cards = shown.values.filter(\.isCard).sorted { $0.event.start < $1.event.start }
        let area = screen.visibleFrame
        let corner = model.settings.alertCorner
        let onLeft = corner == .topLeft || corner == .bottomLeft
        let onTop = corner == .topLeft || corner == .topRight
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        var offset: CGFloat = Self.margin
        for card in cards {
            let size = card.panel.frame.size
            let x = onLeft ? area.minX + Self.margin : area.maxX - size.width - Self.margin
            let y = onTop ? area.maxY - size.height - offset : area.minY + offset
            let slot = NSPoint(x: x, y: y)
            offset += size.height + Self.gap

            if card.event.key == newKey {
                let start = reduceMotion ? slot : NSPoint(x: onLeft ? x - 24 : x + 24, y: y)
                card.panel.setFrameOrigin(start)
                card.panel.alphaValue = reduceMotion ? 1 : 0
                card.panel.orderFrontRegardless()
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0 : 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                card.panel.animator().setFrameOrigin(slot)
                card.panel.animator().alphaValue = 1
            }
        }
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

    private func dismiss(_ key: String) {
        guard let entry = shown.removeValue(forKey: key) else { return }
        entry.panel.orderOut(nil)
        // Called from a button inside the window: let the click finish before the window goes away.
        DispatchQueue.main.async { entry.panel.close() }
        if entry.isCard, let screen = entry.panel.screen ?? Self.screen(for: model.settings.alertDisplayID) {
            layoutCards(on: screen)
        }
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
                .foregroundStyle(AlertFacts.headlineTint(event: event, now: now))
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

    /// Quiet before the start, accent as it starts, orange once you're late. Text says the same thing,
    /// so colour is only reinforcement.
    static func headlineTint(event: CalendarEvent, now: Date) -> Color {
        let sinceStart = now.timeIntervalSince(event.start)
        if sinceStart < 0 { return .secondary }
        return sinceStart < 60 ? .accentColor : .orange
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
