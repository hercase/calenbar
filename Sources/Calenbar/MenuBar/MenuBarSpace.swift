import AppKit
import ApplicationServices
import Observation

/// Live Accessibility permission state. macOS posts a distributed notification whenever any app's
/// Accessibility access changes; the new value is readable a moment later.
@MainActor
@Observable
final class AccessibilityTrust {
    static let shared = AccessibilityTrust()

    private(set) var isTrusted = AXIsProcessTrusted()

    private init() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AccessibilityTrust.shared.isTrusted = AXIsProcessTrusted()
            }
        }
    }
}

/// Finds where the active app's menus end, so the title can use the free space up to them.
/// Reading another app's menu bar requires the Accessibility permission.
enum MenuBarSpace {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (which links to Privacy & Security › Accessibility).
    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Right edge, in screen coordinates, of the frontmost app's last menu (e.g. "Help").
    static func appMenusMaxX() -> CGFloat? {
        guard isTrusted, let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar = element(app, kAXMenuBarAttribute),
            let items = value(menuBar, kAXChildrenAttribute) as? [AXUIElement],
            let last = items.last,
            let origin = point(last, kAXPositionAttribute),
            let size = size(last, kAXSizeAttribute)
        else { return nil }
        // AX uses top-left-origin global coordinates; the x axis matches AppKit's.
        return origin.x + size.width
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(raw, to: AXUIElement.self)
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        // swiftlint:disable:next force_cast
        return AXValueGetValue(raw as! AXValue, .cgPoint, &point) ? point : nil
    }

    private static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        return AXValueGetValue(raw as! AXValue, .cgSize, &size) ? size : nil
    }
}
