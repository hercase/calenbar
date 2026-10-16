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
            } else if model.calendar.calendars.isEmpty {
                NoCalendarsView(model: model)
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
            FooterView(model: model, state: state, openSettings: openSettings)
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

/// Access is granted but macOS has no calendars: the account step from the setup guide.
private struct NoCalendarsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.small) {
            Text("No calendars yet").font(.headline)
            Text("Add your Google, Exchange or iCloud account in System Settings › Internet Accounts and turn on Calendars.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: PanelStyle.small) {
                Button("Open Internet Accounts") { CalendarService.openInternetAccountsSettings() }
                    .buttonStyle(.borderedProminent)
                Button("Refresh") { model.calendar.refreshSources() }
            }
        }
        .padding(PanelStyle.large)
    }
}

/// Bottom bar: today's date (or an update notice) on the left, everything else behind "•••".
private struct FooterView: View {
    let model: AppModel
    let state: PanelState
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: PanelStyle.medium) {
            if let update = model.updater.pending {
                Button {
                    model.updater.checkForUpdates()
                } label: {
                    Label(
                        update.isReadyToInstall
                            ? String(localized: "Update ready · \(update.version)")
                            : String(localized: "Update available · \(update.version)"),
                        systemImage: update.isReadyToInstall
                            ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.down.circle.fill"
                    )
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, PanelStyle.small)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help(
                    update.isReadyToInstall
                        ? String(localized: "Restart Calenbar to finish updating")
                        : String(localized: "Install the new version"))
            } else {
                Text(model.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            IconButton(
                systemImage: state.isPanelPinned ? "pin.fill" : "pin",
                label: state.isPanelPinned
                    ? String(localized: "Let the panel close by itself") : String(localized: "Keep the panel open"),
                tint: state.isPanelPinned ? .accentColor : .secondary
            ) {
                state.isPanelPinned.toggle()
            }
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
                Text(
                    model.settings.titleHorizon == .today
                        ? String(localized: "No more events today") : String(localized: "Nothing coming up")
                )
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

    /// First upcoming event beyond the menu bar's horizon (skipped and declined ones excluded).
    private var next: CalendarEvent? {
        model.events(for: .title).first { $0.start > model.now }
    }

    /// "Tomorrow 10:00 AM", "Monday 10:00 AM", or just "4:00 PM" when it's still today.
    private static func when(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return time
        }
        let day =
            Calendar.current.isDateInTomorrow(date)
            ? String(localized: "Tomorrow")
            : date.formatted(.dateTime.weekday(.wide))
        return "\(day) \(time)"
    }
}
