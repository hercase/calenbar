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
                view: AnyView(GeneralSettings(settings: model.settings, calendar: model.calendar, uiState: uiState))),
            Page(
                title: String(localized: "Menu Bar"), symbol: "menubar.rectangle",
                view: AnyView(MenuBarSettings(settings: model.settings))),
            Page(title: String(localized: "Calendars"), symbol: "calendar", view: AnyView(CalendarSettings(model: model))),
            Page(
                title: String(localized: "Notifications"), symbol: "bell.badge",
                view: AnyView(
                    NotificationSettings(settings: model.settings, scheduler: model.notifications, alerts: model.alerts))),
            Page(
                title: String(localized: "Time Zones"), symbol: "globe",
                view: AnyView(WorldClockSettings(settings: model.settings, uiState: uiState, clock: model.clock))),
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
    let uiState: SettingsUIState

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show month calendar in the panel", isOn: $settings.showMonthCalendar)
                Toggle("Show week numbers in the month calendar", isOn: $settings.showWeekNumbers)
                    .disabled(!settings.showMonthCalendar)
                Toggle("Show free time between meetings", isOn: $settings.showFreeTime)
            }
            FreeTimeSettings(settings: settings, calendar: calendar)
            Section {
                LabeledContent {
                    Button("Refresh Now") { calendar.refreshSources() }
                } label: {
                    Text("Calendar sync")
                    LastReloadText(calendar: calendar)
                }
            } header: {
                Text("Sync")
            } footer: {
                SettingsFooter {
                    Text("settings.sync.footer")
                    Button("Open Calendar…") { calendar.openCalendarApp() }
                        .buttonStyle(.link)
                }
            }
            Section {
                LabeledContent("Join the next meeting from anywhere") {
                    ShortcutRecorder(settings: settings, uiState: uiState)
                }
                Picker("Open meeting links in", selection: $settings.meetingBrowserID) {
                    Text("Default browser").tag("")
                    ForEach(MeetingOpener.installedBrowsers()) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                Toggle("Use the Zoom and Teams apps when installed", isOn: $settings.preferNativeMeetingApps)
                TextField(
                    "Your personal meeting room", text: $settings.personalRoomURL,
                    prompt: Text(verbatim: "https://meet.google.com/abc-defg-hij")
                )
                .textFieldStyle(.roundedBorder)
                Picker("Open events and invitations in", selection: $settings.openEventsIn) {
                    Text("Automatic (Google Calendar for Google events)").tag(EventDestination.automatic)
                    Text("Calendar app").tag(EventDestination.calendarApp)
                    Text("Google Calendar (web)").tag(EventDestination.googleWeb)
                }
            } header: {
                Text("Meetings & events")
            } footer: {
                SettingsFooter { Text("settings.shortcut.footer") }
            }
            AccountProfileSettings(settings: settings, calendar: calendar)
        }
        .formStyle(.grouped)
    }
}

/// Its own view, so a reload re-renders this line and not the whole General form.
private struct LastReloadText: View {
    let calendar: CalendarService

    var body: some View {
        if let last = calendar.lastReload {
            Text("Last updated \(last.formatted(.relative(presentation: .named)))")
        }
    }
}

/// What the menu bar shows and how much room it takes.
private struct MenuBarSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Show the next event up to", selection: $settings.titleHorizon) {
                    Text("1 hour ahead").tag(TitleHorizon.oneHour)
                    Text("2 hours ahead").tag(TitleHorizon.twoHours)
                    Text("4 hours ahead").tag(TitleHorizon.fourHours)
                    Text("8 hours ahead").tag(TitleHorizon.eightHours)
                    Text("End of today").tag(TitleHorizon.today)
                    Text("End of tomorrow").tag(TitleHorizon.throughTomorrow)
                    Text("2 days ahead").tag(TitleHorizon.twoDays)
                    Text("7 days ahead").tag(TitleHorizon.sevenDays)
                }
                Picker("Switch to the next event", selection: $settings.titleRule) {
                    Text("5 min before it starts").tag(TitleRule.switchBeforeNextStarts)
                    Text("5 min before the current one ends").tag(TitleRule.switchBeforeCurrentEnds)
                }
                Toggle("Show the event's card when the pointer rests on the item", isOn: $settings.hoverPreview)
            } header: {
                Text("Next event")
            } footer: {
                SettingsFooter { Text("settings.horizon.footer") }
            }
            Section {
                Toggle("Hide event titles", isOn: $settings.hideTitlesInMenuBar)
            } header: {
                Text("Sharing your screen")
            } footer: {
                SettingsFooter { Text("settings.privacy.footer") }
            }
            Section {
                Picker("Title width", selection: $settings.titleWidth) {
                    Text("Automatic").tag(TitleWidth.automatic)
                    Text("Short").tag(TitleWidth.short)
                    Text("Medium").tag(TitleWidth.medium)
                    Text("Long").tag(TitleWidth.long)
                }
            } header: {
                Text("Width")
            } footer: {
                SettingsFooter { Text("settings.width.footer") }
            }
            Section {
                Text("settings.position.row")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Position")
            }
        }
        .formStyle(.grouped)
    }
}

/// Explanatory text under a section. Grouped forms align footers to the trailing edge on macOS, which
/// reads wrong for paragraphs; this keeps them leading and in the secondary caption style.
struct SettingsFooter<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.tight) {
            content
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NotificationSettings: View {
    @Bindable var settings: AppSettings
    let scheduler: NotificationScheduler?
    let alerts: FullScreenAlertController?

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
                Toggle("Flash red in the menu bar", isOn: $settings.flashEnabled)
                Toggle("Start 5 minutes before (flashes at the end of each minute)", isOn: $settings.flashFromFiveMinutes)
                    .disabled(!settings.flashEnabled)
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

private struct AboutView: View {
    @Bindable var updater: Updater
    private let website = URL(string: "https://keis.studio/?utm_source=calenbar&utm_medium=app&utm_campaign=about")
    private let site = URL(string: "https://hercase.github.io/calenbar/?utm_source=calenbar&utm_medium=app&utm_campaign=about")
    private let issues = URL(string: "https://github.com/hercase/calenbar/issues/new")

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
                    Toggle("Download and install updates automatically", isOn: $updater.automaticallyDownloads)
                }
            }
            Section {
                if let website {
                    LabeledContent("Made by") {
                        Link(destination: website) {
                            HStack(spacing: 6) {
                                StudioMark()
                                Text(verbatim: "keis.studio")
                            }
                        }
                    }
                }
                if let site {
                    LabeledContent("Website") { Link("hercase.github.io/calenbar", destination: site) }
                }
                if let issues {
                    LabeledContent("Something wrong?") { Link("Report a problem", destination: issues) }
                }
            } header: {
                Text("Links")
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
