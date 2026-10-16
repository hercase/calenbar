import CalenbarCore
import SwiftUI

/// One row per calendar, grouped by account, with a checkbox per place it can appear.
struct CalendarSettings: View {
    let model: AppModel

    private struct Column {
        let purpose: CalendarPurpose
        let title: String
        let help: String
    }

    private static let columns = [
        Column(purpose: .list, title: String(localized: "List"), help: String(localized: "Show in the panel's list")),
        Column(
            purpose: .title, title: String(localized: "Menu bar"),
            help: String(localized: "Let it be the event shown in the menu bar")),
        Column(
            purpose: .notify, title: String(localized: "Notify"), help: String(localized: "Send a notification before its events")
        ),
        Column(
            purpose: .alert, title: String(localized: "Alert"),
            help: String(localized: "Show the full-screen alert for its events")),
    ]
    private static let columnWidth: CGFloat = 64

    var body: some View {
        let groups = groupedCalendars
        Form {
            ForEach(Array(groups.enumerated()), id: \.element.account) { index, group in
                Section {
                    if index == 0 {
                        columnHeaders
                    }
                    ForEach(group.calendars) { info in
                        row(info)
                    }
                } header: {
                    Text(group.account)
                } footer: {
                    if index == groups.count - 1 {
                        footer
                    }
                }
            }
            if groups.isEmpty {
                Section {
                    Text("settings.calendars.noAccount")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } footer: {
                    footer
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Accounts first (Google, Exchange, iCloud), then what every Mac has (local, subscribed, birthdays).
    private var groupedCalendars: [(account: String, calendars: [CalendarInfo])] {
        let all = model.calendar.calendars
        let accounts = all.filter(\.isFromAccount).map(\.sourceTitle)
        let others = all.filter { !$0.isFromAccount }.map(\.sourceTitle)
        var seen: Set<String> = []
        return (accounts + others)
            .filter { seen.insert($0).inserted }
            .map { account in (account, all.filter { $0.sourceTitle == account }) }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("Calendar")
            Spacer(minLength: 0)
            ForEach(Self.columns, id: \.purpose) { column in
                Text(column.title)
                    .frame(width: Self.columnWidth)
                    .help(column.help)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    private func row(_ info: CalendarInfo) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: PanelStyle.small) {
                Circle().fill(Color(hex: info.colorHex)).frame(width: 10, height: 10)
                Text(info.title).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: PanelStyle.small)
            ForEach(Self.columns, id: \.purpose) { column in
                Toggle(
                    column.title,
                    isOn: Binding(
                        get: { model.settings.isEnabled(calendarID: info.id, for: column.purpose) },
                        set: { model.settings.setEnabled($0, calendarID: info.id, for: column.purpose) }
                    )
                )
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: Self.columnWidth)
                .help(column.help)
                .accessibilityLabel("\(column.title): \(info.title)")
            }
        }
        .contextMenu {
            Button("Hide from Calenbar") { setAll(false, for: info) }
            Button("Show Everywhere") { setAll(true, for: info) }
            Divider()
            Button("Manage in Calendar…") { model.calendar.openCalendarApp() }
        }
    }

    /// Hide = unchecked everywhere: the calendar stays on the Mac, Calenbar just ignores it.
    private func setAll(_ enabled: Bool, for info: CalendarInfo) {
        for purpose in CalendarPurpose.allCases {
            model.settings.setEnabled(enabled, calendarID: info.id, for: purpose)
        }
    }

    private var footer: some View {
        SettingsFooter {
            Text(
                model.calendar.hasAccountCalendar
                    ? String(localized: "settings.calendars.footer") : String(localized: "settings.calendars.noAccount"))
            HStack(spacing: PanelStyle.medium) {
                Button("Add Account…") { CalendarService.openInternetAccountsSettings() }
                Button("Open Calendar") { model.calendar.openCalendarApp() }
            }
            .buttonStyle(.link)
        }
    }
}
