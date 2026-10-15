import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusBar: StatusBarController?
    private var panel: PanelController?
    private var notifications: NotificationScheduler?
    private var alerts: FullScreenAlertController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel(settings: AppSettings(), calendar: CalendarService(), clock: MinuteClock())
        self.model = model

        let panel = PanelController(model: model) { [weak self] in self?.showSettings() }
        self.panel = panel
        statusBar = StatusBarController(model: model) { button in panel.toggle(from: button) }
        notifications = NotificationScheduler(model: model)
        alerts = FullScreenAlertController(model: model)
        model.updates.start()
        observeContinuously {
            MeetingOpener.browserBundleID = model.settings.meetingBrowserID
            MeetingOpener.preferNativeApps = model.settings.preferNativeMeetingApps
        }

        Task {
            if model.calendar.access == .notDetermined {
                await model.calendar.requestAccess()
            }
            if model.calendar.access == .granted {
                await notifications?.requestAuthorization()
            }
            LoginLaunch.enableOnFirstRun()
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
