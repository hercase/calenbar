import AppKit
import SwiftUI

/// Rest the pointer on the menu bar item and the event's card appears under it, without opening the
/// panel: time, room, who's coming, Join. A short delay keeps passing by quiet, and the card stays
/// while the pointer is on it.
@MainActor
final class HoverPreview: NSObject {
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
        super.init()
        button.addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }

    @objc func mouseEntered(with event: NSEvent) {
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

    @objc func mouseExited(with event: NSEvent) {
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
