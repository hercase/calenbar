import CalenbarCore
import SwiftUI

/// The event shown in the menu bar, as one compact row:
/// a small Join button, then title and "In 10 min · 4:00 – 5:00 PM".
struct HeroEventView: View {
    let model: AppModel
    let event: CalendarEvent

    var body: some View {
        let link = event.meetingLink
        let isUpcoming = event.start > model.now

        HStack(alignment: .center, spacing: PanelStyle.medium) {
            if let link {
                Button {
                    MeetingOpener.open(link)
                } label: {
                    HStack(spacing: 6) {
                        ProviderIconView(provider: link.provider, size: 16)
                        Text("Join")
                    }
                    .padding(.horizontal, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help("Join \(link.provider.displayName) (Return)")
            } else {
                CalendarColorBar(colorHex: event.calendarColorHex, needsResponse: event.needsResponse)
                    .frame(height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(TitleFormatter.displayTitle(event))
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 0) {
                    Text(Self.when(event, now: model.now))
                    Text(" · \(EventTimeText.range(event))")
                    if event.needsResponse {
                        Text(" · Not answered").foregroundStyle(.orange.opacity(0.9))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .help(TitleFormatter.displayTitle(event))

            Spacer(minLength: 0)

            if isUpcoming {
                IconButton(
                    systemImage: "eye.slash",
                    label: "Skip this event: hide it from the menu bar and don't alert"
                ) {
                    model.settings.toggleSkipped(event)
                }
            }
        }
        .padding(.horizontal, PanelStyle.inset)
        .padding(.vertical, PanelStyle.medium)
        .contentShape(Rectangle())
        .contextMenu { EventContextMenu(model: model, event: event) }
    }

    /// "In 10 min" / "Ends in 6 min" / "Now".
    static func when(_ event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            if now.timeIntervalSince(event.start) < 60 {
                return "Now"
            }
            return "Ends in \(TitleFormatter.compactDuration(event.end.timeIntervalSince(now)))"
        }
        return "In \(TitleFormatter.compactDuration(event.start.timeIntervalSince(now)))"
    }
}

/// Right-click actions shared by the hero row and the event list.
struct EventContextMenu: View {
    let model: AppModel
    let event: CalendarEvent

    var body: some View {
        if let link = event.meetingLink {
            Button("Join \(link.provider.displayName)") { MeetingOpener.open(link) }
            Button("Copy Meeting Link") { MeetingOpener.copy(link) }
            Divider()
        }
        if event.needsResponse {
            Button("Answer in \(model.eventDestinationName(event))…") { model.openEvent(event) }
        }
        Button("Open in \(model.eventDestinationName(event))") { model.openEvent(event) }
        Divider()
        Button(model.isSkipped(event) ? "Unskip" : "Skip Event") { model.settings.toggleSkipped(event) }
    }
}

enum EventTimeText {
    static func range(_ event: CalendarEvent) -> String {
        if event.isAllDay {
            return "All day"
        }
        let format = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(event.start.formatted(format)) – \(event.end.formatted(format))"
    }

    /// Right-aligned hint in the list: `in 47 min`, `now`, or nothing for past events.
    static func relative(_ event: CalendarEvent, now: Date) -> String? {
        if event.isAllDay || event.end <= now {
            return nil
        }
        if event.isOngoing(at: now) {
            return "now"
        }
        let delta = event.start.timeIntervalSince(now)
        guard delta < 12 * 3_600 else { return nil }
        return "in \(TitleFormatter.compactDuration(delta))"
    }
}
