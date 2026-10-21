import AppKit

/// Asks before quitting from the menus. Only these entry points ask: logout, restart and the
/// updater's relaunch call NSApp.terminate directly and must never be blocked by a dialog.
@MainActor
enum QuitConfirmation {
    static func run() {
        // A menu bar app is never frontmost; without this the alert opens behind the active app.
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Quit Calenbar?")
        alert.informativeText = String(localized: "quit.explanation")
        alert.addButton(withTitle: String(localized: "Quit"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        NSApp.terminate(nil)
    }
}
