import AppKit
import CalenbarCore
import SwiftUI

/// Settings window with icon tabs in the toolbar, like native macOS preference windows.
@MainActor
enum SettingsWindow {
    static let pageSize = NSSize(width: 560, height: 480)

    struct Page {
        let title: String
        let symbol: String
        let view: AnyView
    }

    static func pages(model: AppModel, uiState: SettingsUIState) -> [Page] {
        [
            Page(
                title: String(localized: "General"), symbol: "gearshape",
                view: AnyView(GeneralSettings(settings: model.settings, calendar: model.calendar))),
            Page(title: String(localized: "Calendars"), symbol: "calendar", view: AnyView(CalendarSettings(model: model))),
            Page(
                title: String(localized: "Notifications"), symbol: "bell.badge",
                view: AnyView(NotificationSettings(settings: model.settings))),
            Page(
                title: String(localized: "Time Zones"), symbol: "globe",
                view: AnyView(WorldClockSettings(settings: model.settings, uiState: uiState))),
            Page(title: String(localized: "About"), symbol: "info.circle", view: AnyView(AboutView(updater: model.updater))),
        ]
    }

    static func make(model: AppModel, uiState: SettingsUIState) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true

        for page in pages(model: model, uiState: uiState) {
            let controller = NSHostingController(rootView: page.view.frame(width: pageSize.width, height: pageSize.height))
            // Fixed size per page: otherwise the window can end up narrower than the content and clip it,
            // which also hides the grouped form's margins.
            controller.sizingOptions = []
            controller.preferredContentSize = pageSize
            controller.title = page.title
            let item = NSTabViewItem(viewController: controller)
            item.label = page.title
            item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.setContentSize(pageSize)
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

private struct GeneralSettings: View {
    @Bindable var settings: AppSettings
    let calendar: CalendarService

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            Picker("Switch to the next event", selection: $settings.titleRule) {
                Text("5 min before it starts").tag(TitleRule.switchBeforeNextStarts)
                Text("5 min before the current one ends").tag(TitleRule.switchBeforeCurrentEnds)
            }
            Toggle("Show month calendar in the panel", isOn: $settings.showMonthCalendar)
            Section {
                LabeledContent("Measure app menus") {
                    if AccessibilityTrust.shared.isTrusted {
                        Label("On", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Allow…") {
                            MenuBarSpace.requestTrust()
                            MenuBarSpace.openAccessibilitySettings()
                        }
                    }
                }
            } footer: {
                Text("settings.menuSpace.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Last updated") {
                    HStack(spacing: PanelStyle.small) {
                        if let last = calendar.lastReload {
                            Text(last, format: .relative(presentation: .named))
                                .foregroundStyle(.secondary)
                        }
                        Button("Refresh Now") { calendar.refreshSources() }
                    }
                }
            } header: {
                Text("Sync")
            } footer: {
                VStack(alignment: .leading, spacing: PanelStyle.tight) {
                    Text("settings.sync.footer")
                    Button("Open Calendar…") { calendar.openCalendarApp() }
                        .buttonStyle(.link)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section("Meetings & events") {
                Picker("Open meeting links in", selection: $settings.meetingBrowserID) {
                    Text("Default browser").tag("")
                    ForEach(MeetingOpener.installedBrowsers()) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                Toggle("Use the Zoom and Teams apps when installed", isOn: $settings.preferNativeMeetingApps)
                Picker("Open events and invitations in", selection: $settings.openEventsIn) {
                    Text("Automatic (Google Calendar for Google events)").tag(EventDestination.automatic)
                    Text("Calendar app").tag(EventDestination.calendarApp)
                    Text("Google Calendar (web)").tag(EventDestination.googleWeb)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CalendarSettings: View {
    let model: AppModel

    var body: some View {
        Table(model.calendar.calendars) {
            TableColumn("Calendar") { info in
                HStack {
                    Circle().fill(Color(hex: info.colorHex)).frame(width: 10, height: 10)
                    VStack(alignment: .leading) {
                        Text(info.title)
                        Text(info.sourceTitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 180)
            column(String(localized: "List"), .list)
            column(String(localized: "Menu bar"), .title)
            column(String(localized: "Notify"), .notify)
            column(String(localized: "Alert"), .alert)
        }
        .padding()
    }

    private func column(_ title: String, _ purpose: CalendarPurpose) -> TableColumn<CalendarInfo, Never, some View, Text> {
        TableColumn(title) { info in
            Toggle(
                title,
                isOn: Binding(
                    get: { model.settings.isEnabled(calendarID: info.id, for: purpose) },
                    set: { model.settings.setEnabled($0, calendarID: info.id, for: purpose) }
                )
            )
            .labelsHidden()
        }
        .width(64)
    }
}

private struct NotificationSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Notification") {
                Toggle("Notify before events", isOn: $settings.notificationsEnabled)
                Picker("When", selection: $settings.notifyLeadMinutes) {
                    ForEach(AppSettings.notifyLeadOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? String(localized: "At start time") : String(localized: "\(minutes) min before")).tag(
                            minutes)
                    }
                }
                .disabled(!settings.notificationsEnabled)
            }
            Section("Grab attention when an event is close") {
                Toggle("Flash red in the menu bar", isOn: $settings.flashEnabled)
                Toggle("Start 5 minutes before (flashes at the end of each minute)", isOn: $settings.flashFromFiveMinutes)
                    .disabled(!settings.flashEnabled)
                Toggle("Play a sound at 5 min and 30 s", isOn: $settings.attentionSound)
            }
            Section("Full-screen alert") {
                Toggle("Show full-screen alert", isOn: $settings.alertEnabled)
                Picker("When", selection: $settings.alertLeadMinutes) {
                    ForEach(AppSettings.notifyLeadOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? String(localized: "At start time") : String(localized: "\(minutes) min before")).tag(
                            minutes)
                    }
                }
                .disabled(!settings.alertEnabled)
                Toggle("Only for events with a meeting link", isOn: $settings.alertOnlyWithLink)
                    .disabled(!settings.alertEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutView: View {
    let updater: Updater
    private let website = URL(string: "https://hercase.vercel.app/")
    private let repository = URL(string: "https://github.com/hercase/calenbar")
    private let issues = URL(string: "https://github.com/hercase/calenbar/issues/new")
    private let sparkle = URL(string: "https://sparkle-project.org")

    var body: some View {
        Form {
            Section {
                HStack(spacing: PanelStyle.large) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calenbar").font(.title2.weight(.semibold))
                        Text("Version \(version)")
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Your next meeting, always in the menu bar.")
                            .font(.callout)
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, PanelStyle.tight)
            }
            Section("Updates") {
                UpdateStatusView(updater: updater)
                if updater.isAvailable {
                    Toggle(
                        "Download and install updates automatically",
                        isOn: Binding(get: { updater.automaticallyDownloads }, set: { updater.automaticallyDownloads = $0 })
                    )
                }
            }
            Section {
                if let website {
                    LabeledContent("Made by Hernan Case") { Link("hercase.vercel.app", destination: website) }
                }
                if let repository {
                    LabeledContent("Source code") { Link("github.com/hercase/calenbar", destination: repository) }
                }
                if let issues {
                    LabeledContent("Something wrong?") { Link("Report a problem", destination: issues) }
                }
            } header: {
                Text("Links")
            } footer: {
                HStack(spacing: PanelStyle.tight) {
                    Text("Updates are delivered with")
                    if let sparkle {
                        Link("Sparkle", destination: sparkle)
                    }
                    Text(verbatim: "· © 2026 Hernan Case")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, PanelStyle.tight)
            }
        }
        .formStyle(.grouped)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}

/// One row: the state on the left ("Last checked 2 hours ago", "0.4.0 is ready to install"), the action
/// on the right. The button checks, downloads or installs depending on where things stand.
private struct UpdateStatusView: View {
    let updater: Updater

    var body: some View {
        LabeledContent {
            if let update = updater.pending {
                Button(
                    update.isReadyToInstall
                        ? String(localized: "Install and Relaunch")
                        : String(localized: "Update to \(update.version)…")
                ) { updater.checkForUpdates() }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Check for Updates…") { updater.checkForUpdates() }
            }
        } label: {
            Text("Updates")
            if let update = updater.pending {
                Text(
                    update.isReadyToInstall
                        ? String(localized: "Version \(update.version) is ready to install.")
                        : String(localized: "Version \(update.version) is available."))
            } else if let last = updater.lastCheck {
                Text("Last checked \(last.formatted(.relative(presentation: .named)))")
            } else if !updater.isAvailable {
                Text("Not available in this build.")
            }
        }
        .disabled(!updater.canCheck)
    }
}
