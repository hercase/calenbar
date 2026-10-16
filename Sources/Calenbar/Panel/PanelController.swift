import AppKit
import SwiftUI

/// Shows the panel as a popover anchored to the menu bar item; closes on outside click or Esc.
@MainActor
final class PanelController {
    private let popover = NSPopover()
    private let state = PanelState()

    private let model: AppModel

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        popover.behavior = .transient
        popover.animates = false
        let hosting = NSHostingController(
            rootView: PanelView(
                model: model, state: state,
                openSettings: { [weak popover] in
                    popover?.performClose(nil)
                    openSettings()
                }))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        observeContinuously { [weak self, state] in
            self?.popover.behavior = state.isPanelPinned ? .applicationDefined : .transient
        }
    }

    func toggle(from button: NSStatusBarButton) {
        if popover.isShown {
            state.isPanelPinned = false
            popover.performClose(nil)
        } else {
            state.resetToToday()
            // Looking at the panel is when fresh data matters most: ask macOS to sync now.
            model.calendar.refreshSources()
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
