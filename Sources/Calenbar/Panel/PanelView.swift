import CalenbarCore
import SwiftUI

struct PanelView: View {
    let model: AppModel
    let state: PanelState
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.calendar.access != .granted {
                AccessRequiredView(model: model)
            } else {
                if let event = model.titleEvent {
                    HeroEventView(model: model, event: event)
                } else {
                    DoneForTodayView(model: model)
                }
                PanelDivider()
                MiniCalendarView(model: model, state: state)
                PanelDivider()
                EventListView(model: model, state: state)
                if model.settings.showClocksInPanel, !model.settings.worldClocks.isEmpty {
                    PanelDivider()
                    WorldClocksView(clocks: model.settings.worldClocks, now: model.now)
                }
            }
            PanelDivider()
            FooterView(model: model, openSettings: openSettings)
        }
        .frame(width: PanelStyle.width)
    }
}

private struct AccessRequiredView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.small) {
            Text("Calendar access needed").font(.headline)
            Text("Calenbar reads your events from the macOS Calendar app. Nothing leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if model.calendar.access == .notDetermined {
                Button("Allow Access") { Task { await model.calendar.requestAccess() } }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Open Privacy Settings") { CalendarService.openPrivacySettings() }
            }
        }
        .padding(PanelStyle.large)
    }
}

/// Bottom bar: today's date (or an update notice) on the left, everything else behind "•••".
private struct FooterView: View {
    let model: AppModel
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: PanelStyle.medium) {
            if let update = model.updates.available {
                Button {
                    model.updates.openReleasePage()
                } label: {
                    Label("Update available · \(update.version.description)", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, PanelStyle.small)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Download the new version from GitHub")
            } else {
                Text(model.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Open Calendar") { model.calendar.openCalendarApp() }
                Button("Settings…", action: openSettings)
                    .keyboardShortcut(",")
                Divider()
                Button("Quit Calenbar") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
            .accessibilityLabel("More")
        }
        .padding(.horizontal, PanelStyle.inset)
        .padding(.vertical, PanelStyle.small + 2)
    }
}

/// Top row when nothing is left today: mirrors the menu bar's checkmark icon and previews what's next.
private struct DoneForTodayView: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: PanelStyle.medium) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("No more events today")
                    .font(.headline)
                if let next {
                    Text(verbatim: "\(Self.when(next.start)) · \(TitleFormatter.displayTitle(next))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Nothing scheduled this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PanelStyle.inset)
        .padding(.vertical, PanelStyle.medium)
    }

    /// First upcoming event after today (skipped and declined ones excluded).
    private var next: CalendarEvent? {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: model.now))
        return model.events(for: .title).first { event in endOfToday.map { event.start >= $0 } ?? false }
    }

    /// "Tomorrow 10:00 AM" or "Monday 10:00 AM".
    private static func when(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let day =
            Calendar.current.isDateInTomorrow(date)
            ? String(localized: "Tomorrow")
            : date.formatted(.dateTime.weekday(.wide))
        return "\(day) \(time)"
    }
}
