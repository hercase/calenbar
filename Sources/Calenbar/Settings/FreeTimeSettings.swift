import SwiftUI

/// Default length of a block, and which calendar receives a focus or lunch block.
struct FreeTimeSettings: View {
    @Bindable var settings: AppSettings
    let calendar: CalendarService

    var body: some View {
        Section {
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
