import AppKit
import CalenbarCore
import SwiftUI

/// Settings window with icon tabs in the toolbar, like native macOS preference windows.
@MainActor
enum SettingsWindow {
    private static let pageSize = NSSize(width: 560, height: 480)

    static func make(model: AppModel, uiState: SettingsUIState) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true

        func add(_ title: String, _ symbol: String, _ view: some View) {
            let page = NSHostingController(rootView: view.frame(width: pageSize.width, height: pageSize.height))
            // Fixed size per page: otherwise the window can end up narrower than the content and clip it,
            // which also hides the grouped form's margins.
            page.sizingOptions = []
            page.preferredContentSize = pageSize
            page.title = title
            let item = NSTabViewItem(viewController: page)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        add(String(localized: "General"), "gearshape", GeneralSettings(settings: model.settings, calendar: model.calendar))
        add(String(localized: "Calendars"), "calendar", CalendarSettings(model: model))
        add(String(localized: "Notifications"), "bell.badge", NotificationSettings(settings: model.settings))
        add(String(localized: "Time Zones"), "globe", WorldClockSettings(settings: model.settings, uiState: uiState))
        add(String(localized: "About"), "info.circle", AboutView(updater: model.updater))

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
            Section("Grab attention when an event is close") {
                Toggle("Flash red in the menu bar", isOn: $settings.flashEnabled)
                Toggle("Start 5 minutes before (flashes at the end of each minute)", isOn: $settings.flashFromFiveMinutes)
                    .disabled(!settings.flashEnabled)
                Toggle("Play a sound at 5 min and 30 s", isOn: $settings.attentionSound)
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

    var body: some View {
        VStack(spacing: PanelStyle.medium) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Calenbar").font(.title.weight(.semibold))
            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Your next meeting, always in the menu bar.")
                .font(.callout)
            UpdateStatusView(updater: updater)
            VStack(spacing: PanelStyle.tight) {
                Text("Made by Hernán Case")
                    .font(.callout.weight(.medium))
                if let website {
                    Link("hercase.vercel.app", destination: website)
                        .font(.callout)
                }
            }
            .padding(.top, PanelStyle.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}

/// Sparkle status: one button that checks, downloads or installs depending on where things stand.
private struct UpdateStatusView: View {
    let updater: Updater

    var body: some View {
        VStack(spacing: PanelStyle.small) {
            HStack(spacing: PanelStyle.small) {
                if let update = updater.pending {
                    Button(
                        update.isReadyToInstall
                            ? String(localized: "Install \(update.version) and Relaunch")
                            : String(localized: "Update to \(update.version)…")
                    ) { updater.checkForUpdates() }
                    .buttonStyle(.borderedProminent)
                } else {
                    if let last = updater.lastCheck {
                        Text("Last checked \(last.formatted(.relative(presentation: .named)))")
                            .foregroundStyle(.secondary)
                    }
                    Button("Check for Updates…") { updater.checkForUpdates() }
                }
            }
            .disabled(!updater.canCheck)
            if updater.isAvailable {
                Toggle(
                    "Download and install updates automatically",
                    isOn: Binding(get: { updater.automaticallyDownloads }, set: { updater.automaticallyDownloads = $0 })
                )
                .toggleStyle(.checkbox)
                .font(.caption)
            }
        }
        .font(.callout)
    }
}
