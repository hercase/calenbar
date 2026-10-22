import SwiftUI

/// Default length of a block, and which calendar receives a focus or lunch block.
struct FreeTimeSettings: View {
    @Bindable var settings: AppSettings
    let calendar: CalendarService

    var body: some View {
        Section {
            LabeledContent("Workday") {
                HStack(spacing: PanelStyle.tight) {
                    halfHourPicker(String(localized: "Starts"), selection: $settings.workdayStart) {
                        $0 < settings.workdayEnd
                    }
                    Text(verbatim: "–").foregroundStyle(.secondary)
                    halfHourPicker(String(localized: "Ends"), selection: $settings.workdayEnd) {
                        $0 > settings.workdayStart
                    }
                }
                .fixedSize()
            }
            .disabled(!settings.showFreeTime)
            Picker("Default length", selection: $settings.lunchMinutes) {
                Text("30 minutes").tag(30)
                Text("1 hour").tag(60)
            }
            .disabled(!settings.showFreeTime)
            Picker("Save focus and lunch on", selection: blockCalendarSelection) {
                Text("Default calendar").tag("")
                ForEach(writableCalendars) { info in
                    Text(info.title + " · " + info.sourceTitle).tag(info.id)
                }
            }
            .disabled(!settings.showFreeTime)
        } header: {
            Text("Free time")
        } footer: {
            SettingsFooter { Text("settings.blocks.footer") }
        }
    }

    /// Every half hour from 5:00 to 23:30 that keeps the workday at least half an hour long.
    private func halfHourPicker(
        _ label: String, selection: Binding<Int>, isAllowed: (Int) -> Bool
    ) -> some View {
        Picker(label, selection: selection) {
            ForEach(Array(stride(from: 5 * 60, through: 23 * 60 + 30, by: 30)).filter(isAllowed), id: \.self) { minutes in
                Text(Self.clockTime(minutes)).tag(minutes)
            }
        }
        .labelsHidden()
        .accessibilityLabel(label)
    }

    /// "9:00 AM" or "09:00", the way the system clock is set.
    private static func clockTime(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Account calendars first: those are the ones other people can see as busy.
    private var writableCalendars: [CalendarInfo] {
        let writable = calendar.calendars.filter(\.canCreateEvents)
        return writable.filter(\.isFromAccount) + writable.filter { !$0.isFromAccount }
    }

    /// A calendar that was removed shows as the default instead of a blank row.
    private var blockCalendarSelection: Binding<String> {
        Binding(
            get: { writableCalendars.contains { $0.id == settings.blockCalendarID } ? settings.blockCalendarID : "" },
            set: { settings.blockCalendarID = $0 }
        )
    }
}
