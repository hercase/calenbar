import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A key combination the user recorded: the key's code plus modifier flags.
struct KeyShortcut: Codable, Hashable {
    let keyCode: UInt32
    /// `NSEvent.ModifierFlags` raw value, device-independent bits only.
    let modifiers: UInt
    /// What the key prints, for display ("A", "Space", "F5").
    let keyLabel: String

    /// ⌃⌘J: free in macOS and in the common window managers (which live on Control-Option).
    static let defaultJoin = KeyShortcut(
        keyCode: UInt32(kVK_ANSI_J), modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue, keyLabel: "J")

    init(keyCode: UInt32, modifiers: UInt, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// nil unless the event is a real combination: a key plus ⌘, ⌃ or ⌥ (⇧ alone would collide with typing).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.isDisjoint(with: [.command, .control, .option]) else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = flags.rawValue
        keyLabel = Self.label(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// "⌃⌥⌘J", in the order macOS prints them.
    var display: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + keyLabel
    }

    /// The same combination for a SwiftUI menu item, when the key has a SwiftUI equivalent.
    var keyboardShortcut: KeyboardShortcut? {
        guard let key = keyEquivalent else { return nil }
        var modifiers: SwiftUI.EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return KeyboardShortcut(key, modifiers: modifiers)
    }

    /// The key for an `NSMenuItem`, which displays it next to the title.
    var menuKeyEquivalent: String? {
        if keyLabel == "Space" { return " " }
        guard keyLabel.count == 1, let first = keyLabel.first, first.isLetter || first.isNumber || first.isPunctuation else {
            return nil
        }
        return keyLabel.lowercased()
    }

    private var keyEquivalent: KeyEquivalent? {
        switch keyLabel {
        case "Space": return .space
        case "↩": return .return
        case "⇥": return .tab
        case "⌫": return .delete
        case "←": return .leftArrow
        case "→": return .rightArrow
        case "↑": return .upArrow
        case "↓": return .downArrow
        default:
            guard keyLabel.count == 1, let first = keyLabel.lowercased().first else { return nil }
            return KeyEquivalent(first)
        }
    }

    var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        return mask
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func label(keyCode: UInt16, characters: String?) -> String {
        if let special = specialKeys[Int(keyCode)] {
            return special
        }
        if let first = characters?.first, first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol {
            return String(first).uppercased()
        }
        return "Key \(keyCode)"
    }
}

/// Registers one system-wide shortcut through Carbon, which works inside the App Sandbox and needs no
/// Accessibility permission.
@MainActor
final class HotKeyCenter {
    private static let signature: OSType = 0x434C_4252  // "CLBR"
    /// The Carbon callback is a C function and can't capture; it reaches the live instance through here.
    nonisolated(unsafe) private static weak var current: HotKeyCenter?

    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
        Self.current = self
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                // Carbon delivers hot keys on the main run loop.
                MainActor.assumeIsolated { HotKeyCenter.current?.action() }
                return noErr
            }, 1, &pressed, nil, &handler)
    }

    /// Replaces the registered combination; nil unregisters.
    func set(_ shortcut: KeyShortcut?) {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        guard let shortcut else { return }
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKey)
    }
}
