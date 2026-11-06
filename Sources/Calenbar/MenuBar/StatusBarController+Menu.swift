import AppKit

// MARK: - Right-click menu

extension StatusBarController {
    /// Right click: the same actions as the panel's "•••" menu, without opening the panel.
    func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if let update = model.updater.pending {
            let title =
                update.isReadyToInstall
                ? String(localized: "Restart to Update") : String(localized: "Update to \(update.version)…")
            menu.addItem(withTitle: title, action: #selector(installUpdate), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        let shortcut = model.settings.joinShortcut
        let join = menu.addItem(
            withTitle: String(localized: "Join Next Meeting"), action: #selector(joinNext),
            keyEquivalent: shortcut?.menuKeyEquivalent ?? "")
        join.keyEquivalentModifierMask = shortcut?.flags ?? []
        join.target = self
        join.isEnabled = model.nextMeeting != nil
        menu.addItem(.separator())
        let hide = menu.addItem(
            withTitle: String(localized: "Hide Event Titles"), action: #selector(toggleHideTitles), keyEquivalent: "")
        hide.target = self
        hide.state = model.settings.hideTitlesInMenuBar ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Open Calendar"), action: #selector(openCalendar), keyEquivalent: "").target =
            self
        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit Calenbar"), action: #selector(quit), keyEquivalent: "q").target = self
        // Attaching a menu makes the button pop it up on click; detach right after so left clicks keep opening the panel.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func joinNext() { model.joinNextMeeting() }
    @objc private func installUpdate() { model.updater.checkForUpdates() }
    @objc private func toggleHideTitles() { model.settings.hideTitlesInMenuBar.toggle() }
    @objc private func openCalendar() { model.calendar.openCalendarApp() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { QuitConfirmation.run() }
}
