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
        let model = AppModel(settings: AppSettings(), calendar: CalendarService(), clock: MinuteClock())
        self.model = model

        let panel = PanelController(model: model) { [weak self] in self?.showSettings() }
        self.panel = panel
        statusBar = StatusBarController(
            model: model,
            onOpenSettings: { [weak self] in self?.showSettings() },
            onClick: { button in panel.toggle(from: button) }
        )
        notifications = NotificationScheduler(model: model)
        model.notifications = notifications
        alerts = FullScreenAlertController(model: model)
        model.updater.start()
        observeContinuously {
            MeetingOpener.browserBundleID = model.settings.meetingBrowserID
            MeetingOpener.preferNativeApps = model.settings.preferNativeMeetingApps
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

    private func showSettings() {
        guard let model else { return }
        if settingsWindow == nil {
            settingsWindow = SettingsWindow.make(model: model, uiState: SettingsUIState())
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
