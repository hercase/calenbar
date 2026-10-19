import AppKit
import SwiftUI

/// Rest the pointer on the menu bar item and the event's card appears under it, without opening the
/// panel: time, room, who's coming, Join. A short delay keeps passing by quiet, and the card stays
/// while the pointer is on it.
@MainActor
final class HoverPreview {
    private static let openDelay: TimeInterval = 0.5
    private static let closeGrace: TimeInterval = 0.35

    private let model: AppModel
    private weak var button: NSStatusBarButton?
    private let isPanelOpen: () -> Bool
    private var popover: NSPopover?
    private var openTimer: Timer?
    private var closeTimer: Timer?

    init(model: AppModel, button: NSStatusBarButton, isPanelOpen: @escaping () -> Bool) {
        self.model = model
        self.button = button
        self.isPanelOpen = isPanelOpen
        // An overlay with its own tracking area: the status bar button rebuilds its tracking areas
        // itself and drops any added from outside. The overlay never takes clicks.
        let overlay = TrackingOverlay(frame: button.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.onEnter = { [weak self] in self?.pointerEntered() }
        overlay.onExit = { [weak self] in self?.pointerExited() }
        button.addSubview(overlay)
    }

    private func pointerEntered() {
        closeTimer?.invalidate()
        closeTimer = nil
        let settings = model.settings
        guard settings.hoverPreview, !settings.hideTitlesInMenuBar, popover == nil, !isPanelOpen(), model.titleEvent != nil
        else { return }
        openTimer?.invalidate()
        openTimer = Timer.scheduledTimer(withTimeInterval: Self.openDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.show() }
        }
    }

    private func pointerExited() {
        openTimer?.invalidate()
        openTimer = nil
        scheduleClose()
    }

    func close() {
        openTimer?.invalidate()
        openTimer = nil
        closeTimer?.invalidate()
        closeTimer = nil
        popover?.performClose(nil)
        popover = nil
    }

    private func scheduleClose() {
        closeTimer?.invalidate()
        closeTimer = Timer.scheduledTimer(withTimeInterval: Self.closeGrace, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func show() {
        guard let button, let event = model.titleEvent, popover == nil, !isPanelOpen() else { return }
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        let card = EventDetailView(model: model, event: event)
            // Join, Skip or Open was clicked: the card has done its job.
            .simultaneousGesture(TapGesture().onEnded { [weak self] in self?.scheduleClose() })
            .onHover { [weak self] inside in
                if inside {
                    self?.closeTimer?.invalidate()
                    self?.closeTimer = nil
                } else {
                    self?.scheduleClose()
                }
            }
        popover.contentViewController = NSHostingController(rootView: card)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
    }
}

/// Invisible view that only reports the pointer entering and leaving; clicks go through to the button.
private final class TrackingOverlay: NSView {
    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func mouseEntered(with event: NSEvent) { onEnter() }
    override func mouseExited(with event: NSEvent) { onExit() }
}
