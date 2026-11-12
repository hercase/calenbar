import AppKit
import CalenbarCore
import SwiftUI

struct NotificationSettings: View {
    @Bindable var settings: AppSettings
    let scheduler: NotificationScheduler?
    let alerts: FullScreenAlertController?
    let previewFlash: ((FlashPreview) -> Void)?
    let flashPreviewing: FlashPreview?
    let flashPhaseOn: Bool

    var body: some View {
        Form {
            if scheduler?.isDeniedBySystem == true {
                Section {
                    LabeledContent {
                        Button("Open Notification Settings") { NotificationScheduler.openNotificationSettings() }
                    } label: {
                        Label("Notifications are turned off for Calenbar in macOS", systemImage: "bell.slash")
                        Text("Allow them in System Settings › Notifications › Calenbar to get a heads-up before meetings.")
                    }
                }
            }
            Section("Notification") {
                Toggle("Notify before events", isOn: $settings.notificationsEnabled)
                Picker("When", selection: $settings.notifyLeadMinutes) {
                    ForEach(AppSettings.notifyLeadOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? String(localized: "At start time") : String(localized: "\(minutes) min before")).tag(
                            minutes)
                    }
                }
                .disabled(!settings.notificationsEnabled)
                LabeledContent("Preview") {
                    Button("Send Test Notification") { scheduler?.sendTest() }
                }
                .disabled(!settings.notificationsEnabled || scheduler == nil)
            }
            Section("Grab attention when an event is close") {
                Toggle("Flash red when a meeting is about to start", isOn: $settings.flashEnabled)
                Toggle("Start 5 minutes before (flashes at the end of each minute)", isOn: $settings.flashFromFiveMinutes)
                    .disabled(!settings.flashEnabled)
                Toggle("Flash yellow 10 min before a back-to-back meeting", isOn: $settings.flashFollowUp)
                    .disabled(!settings.flashEnabled)
                HStack(spacing: 12) {
                    FlashMockBar(flash: flashPreviewing, isOn: flashPhaseOn)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        FlashTestButton(
                            color: .red, isRunning: flashPreviewing == .red, action: { previewFlash?(.red) },
                            title: { Text("Starting") })
                        FlashTestButton(
                            color: .yellow, isRunning: flashPreviewing == .yellow, action: { previewFlash?(.yellow) },
                            title: { Text("Up next") }
                        )
                        .disabled(!settings.flashFollowUp)
                    }
                    .disabled(!settings.flashEnabled || previewFlash == nil)
                }
                Toggle("Play a sound at 5 min, at 30 s, and when the alert card appears", isOn: $settings.attentionSound)
            }
            Section {
                Toggle("Show an alert when a meeting starts", isOn: $settings.alertEnabled)
                Picker("Style", selection: $settings.alertStyle) {
                    Text("Small card in a corner").tag(AlertStyle.card)
                    Text("Full screen").tag(AlertStyle.fullScreen)
                }
                .disabled(!settings.alertEnabled)
                if settings.alertStyle == .card {
                    Picker("Corner", selection: $settings.alertCorner) {
                        Text("Bottom right").tag(AlertCorner.bottomRight)
                        Text("Bottom left").tag(AlertCorner.bottomLeft)
                        Text("Top right").tag(AlertCorner.topRight)
                        Text("Top left").tag(AlertCorner.topLeft)
                    }
                    .disabled(!settings.alertEnabled)
                }
                Picker("When", selection: $settings.alertLeadMinutes) {
                    ForEach(AppSettings.notifyLeadOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? String(localized: "At start time") : String(localized: "\(minutes) min before")).tag(
                            minutes)
                    }
                }
                .disabled(!settings.alertEnabled)
                Toggle("Only for events with a meeting link", isOn: $settings.alertOnlyWithLink)
                    .disabled(!settings.alertEnabled)
                Picker("Show it on", selection: $settings.alertDisplayID) {
                    Text("The screen with the pointer").tag(UInt32?.none)
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                }
                .disabled(!settings.alertEnabled)
                LabeledContent("Preview") {
                    Button("Show Test Alert") { alerts?.showPreview() }
                }
                .disabled(!settings.alertEnabled || alerts == nil)
            } header: {
                Text("Alert")
            } footer: {
                SettingsFooter { Text("settings.alert.footer") }
            }
        }
        .formStyle(.grouped)
    }
}
