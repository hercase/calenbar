import AppKit
import CalenbarCore
import SwiftUI

/// Settings window with icon tabs in the toolbar, like native macOS preference windows.
@MainActor
enum SettingsWindow {
    static func make(model: AppModel, uiState: SettingsUIState) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true

        func add(_ title: String, _ symbol: String, _ view: some View) {
            let page = NSHostingController(rootView: view.frame(width: 540, height: 460))
            page.title = title
            let item = NSTabViewItem(viewController: page)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        add("General", "gearshape", GeneralSettings(settings: model.settings, calendar: model.calendar))
        add("Calendars", "calendar", CalendarSettings(model: model))
        add("Notifications", "bell.badge", NotificationSettings(settings: model.settings))
        add("World Clocks", "globe", WorldClockSettings(settings: model.settings, uiState: uiState))
        add("About", "info.circle", AboutView(updates: model.updates))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
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
                Text(
                    """
                    Optional. On displays without a notch, lets long titles use the free space up to the \
                    active app's menus instead of a fixed width. Not needed on a MacBook screen. \
                    Requires Accessibility access, used only to read where the app menus end.
                    """
                )
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
                    Text(
                        """
                        macOS syncs Google and Exchange calendars on its own schedule. For new invitations to \
                        show up quickly, set Calendar › Settings › Accounts › Refresh Calendars to "Every minute".
                        """
                    )
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
            column("List", .list)
            column("Menu bar", .title)
            column("Notify", .notify)
            column("Alert", .alert)
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
                        Text(minutes == 0 ? "At start time" : "\(minutes) min before").tag(minutes)
                    }
                }
                .disabled(!settings.notificationsEnabled)
            }
            Section("Full-screen alert") {
                Toggle("Show full-screen alert", isOn: $settings.alertEnabled)
                Picker("When", selection: $settings.alertLeadMinutes) {
                    ForEach(AppSettings.notifyLeadOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? "At start time" : "\(minutes) min before").tag(minutes)
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

private struct WorldClockSettings: View {
    @Bindable var settings: AppSettings
    @Bindable var uiState: SettingsUIState

    var body: some View {
        Form {
            Section {
                if settings.worldClocks.isEmpty {
                    VStack(spacing: PanelStyle.small) {
                        Image(systemName: "globe")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No world clocks yet").font(.headline)
                        Text("Add the cities you work with. They show at the bottom of the panel.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PanelStyle.large)
                } else {
                    ForEach($settings.worldClocks) { $clock in
                        ClockRow(clock: $clock) {
                            settings.worldClocks.removeAll { $0.id == clock.id }
                        }
                    }
                    .onMove { settings.worldClocks.move(fromOffsets: $0, toOffset: $1) }
                }
            } header: {
                Text("World Clocks")
            } footer: {
                HStack {
                    Spacer()
                    Button("Add Clock…") { uiState.isAddingClock = true }
                        .popover(isPresented: $uiState.isAddingClock, arrowEdge: .bottom) {
                            TimeZonePicker(query: $uiState.timeZoneQuery) { identifier, name in
                                settings.worldClocks.append(WorldClock(timeZoneID: identifier, name: name))
                                uiState.timeZoneQuery = ""
                                uiState.isAddingClock = false
                            }
                        }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ClockRow: View {
    @Binding var clock: WorldClock
    let remove: () -> Void

    var body: some View {
        HStack(spacing: PanelStyle.medium) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $clock.name)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Date().formatted(Self.timeStyle(clock.timeZone)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove \(clock.name)")
            .accessibilityLabel("Remove \(clock.name)")
        }
    }

    private var subtitle: String {
        let zone = clock.timeZoneID.replacingOccurrences(of: "_", with: " ")
        return "\(zone) · \(InlineClocksView.offset(of: clock.timeZone, at: Date()))"
    }

    private static func timeStyle(_ zone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return style
    }
}

/// Search field + results, shown in a popover from "Add Clock…".
private struct TimeZonePicker: View {
    @Binding var query: String
    let pick: (_ identifier: String, _ name: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.small) {
            TextField("Search a city, e.g. Madrid or New York", text: $query)
                .textFieldStyle(.roundedBorder)
            if query.count < 2 {
                Text("Type at least 2 letters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, PanelStyle.tight)
            } else if matches.isEmpty {
                Text("No matching time zones")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, PanelStyle.tight)
            } else {
                List(matches, id: \.self) { identifier in
                    Button {
                        pick(identifier, Self.cityName(identifier))
                    } label: {
                        HStack {
                            Text(Self.cityName(identifier))
                            Spacer()
                            Text(identifier.split(separator: "/").first.map(String.init) ?? "")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 200)
            }
        }
        .padding(PanelStyle.medium)
        .frame(width: 320)
    }

    private var matches: [String] {
        let needle = query.replacingOccurrences(of: " ", with: "_").lowercased()
        return TimeZone.knownTimeZoneIdentifiers.filter { $0.lowercased().contains(needle) }.prefix(30).map { $0 }
    }

    static func cityName(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }
}

private struct AboutView: View {
    let updates: UpdateChecker
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
            UpdateStatusView(updates: updates)
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

private struct UpdateStatusView: View {
    let updates: UpdateChecker

    var body: some View {
        HStack(spacing: PanelStyle.small) {
            if let update = updates.available {
                Button("Download \(update.version.description)") { updates.openReleasePage() }
                    .buttonStyle(.borderedProminent)
            } else if updates.isChecking {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            } else {
                Text(updates.lastCheck == nil ? "" : "You're up to date.")
                    .foregroundStyle(.secondary)
                Button("Check for Updates") { Task { await updates.check() } }
            }
        }
        .font(.callout)
    }
}
