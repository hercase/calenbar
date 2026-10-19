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
                    MeetingOpener.open(link, eventKey: event.key)
                } label: {
                    // Text only: at this size a logo (or a tile behind it) outweighs the word, and
                    // the service already shows in the event's row and card.
                    Text("Join")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help(
                    model.settings.joinShortcut.map {
                        String(localized: "Join \(link.provider.displayName) (Return, or \($0.display) anywhere)")
                    }
                        ?? String(localized: "Join \(link.provider.displayName) (Return)"))
            } else {
                CalendarColorBar(colorHex: event.calendarColorHex, needsResponse: event.needsResponse)
                    .frame(height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(TitleFormatter.displayTitle(event))
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 0) {
                    Text(TitleFormatter.status(for: event, now: model.now))
                    Text(verbatim: " · \(EventTimeText.range(event))")
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
                SkipButton(model: model, event: event)
            }
        }
        .padding(.horizontal, PanelStyle.inset)
        .padding(.vertical, PanelStyle.medium)
        .contentShape(Rectangle())
        .contextMenu { EventContextMenu(model: model, event: event) }
    }
}

/// Right-click actions shared by the hero row and the event list.
struct EventContextMenu: View {
    let model: AppModel
    let event: CalendarEvent

    var body: some View {
        if let link = event.meetingLink {
            Button("Join \(link.provider.displayName)") { MeetingOpener.open(link, eventKey: event.key) }
            Button("Copy Meeting Link") { MeetingOpener.copy(link) }
            Divider()
        }
        if event.needsResponse {
            Button("Answer in \(model.eventDestinationName(event))…") { model.openEvent(event) }
        }
        Button("Open in \(model.eventDestinationName(event))") { model.openEvent(event) }
        Divider()
        Button(model.isSkipped(event) ? String(localized: "Unskip") : String(localized: "Skip Event")) {
            model.settings.toggleSkipped(event)
        }
    }
}

enum EventTimeText {
    static func range(_ event: CalendarEvent, in zone: TimeZone = .current) -> String {
        if event.isAllDay {
            return String(localized: "All day")
        }
        var format = Date.FormatStyle(date: .omitted, time: .shortened)
        format.timeZone = zone
        return "\(event.start.formatted(format)) – \(event.end.formatted(format))"
    }

    /// Right-aligned hint in the list: `in 47 min`, `now`, or nothing for past events.
    static func relative(_ event: CalendarEvent, now: Date) -> String? {
        if event.isAllDay || event.end <= now {
            return nil
        }
        if event.isOngoing(at: now) {
            return String(localized: "now")
        }
        let delta = event.start.timeIntervalSince(now)
        guard delta < 12 * 3_600 else { return nil }
        return String(localized: "in \(TitleFormatter.compactDuration(delta))")
    }
}
