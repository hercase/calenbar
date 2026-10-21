import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusBar: StatusBarController?
    private var panel: PanelController?
    private var notifications: NotificationScheduler?
    private var alerts: FullScreenAlertController?
    private var hotKeys: HotKeyCenter?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if InstallLocation.offerMoveIfNeeded() {
            return
        }
        NSApp.mainMenu = Self.makeMainMenu()
        let model = AppModel(settings: AppSettings(), calendar: CalendarService(), clock: MinuteClock())
        self.model = model

        let panel = PanelController(model: model) { [weak self] in self?.showSettings() }
        self.panel = panel
        statusBar = StatusBarController(
            model: model,
            isPanelOpen: { panel.isShown },
            onOpenSettings: { [weak self] in self?.showSettings() },
            onClick: { button in panel.toggle(from: button) }
        )
        notifications = NotificationScheduler(model: model)
        model.notifications = notifications
        alerts = FullScreenAlertController(model: model)
        model.alerts = alerts
        model.updater.start()
        observeContinuously {
            MeetingOpener.browserBundleID = model.settings.meetingBrowserID
            MeetingOpener.preferNativeApps = model.settings.preferNativeMeetingApps
            MeetingOpener.profileChoices = model.settings.accountProfiles
        }
        let hotKeys = HotKeyCenter { model.joinNextMeeting() }
        self.hotKeys = hotKeys
        observeContinuously { hotKeys.set(model.settings.joinShortcut) }

        Task {
            if model.calendar.access == .notDetermined {
                await model.calendar.requestAccess()
            }
            if !InstallLocation.isTemporary {
                LoginLaunch.enableOnFirstRun()
            }
        }
    }

    /// A menu bar app shows no menus, but key equivalents still go through the main menu: without
    /// an Edit menu, ⌘V does nothing in the Settings text fields.
    private static func makeMainMenu() -> NSMenu {
        let edit = NSMenu(title: String(localized: "Edit"))
        edit.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let window = NSMenu(title: String(localized: "Window"))
        window.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let main = NSMenu()
        for submenu in [edit, window] {
            let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }

    private func showSettings() {
        guard let model else { return }
        if settingsWindow == nil {
            settingsWindow = SettingsWindow.make(model: model, uiState: SettingsUIState())
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
