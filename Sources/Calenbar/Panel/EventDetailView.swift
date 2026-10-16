import CalenbarCore
import SwiftUI

/// Card shown next to a hovered event: calendar, meeting, location and description.
struct EventDetailView: View {
    let model: AppModel
    let event: CalendarEvent

    var body: some View {
        let link = event.meetingLink
        VStack(alignment: .leading, spacing: PanelStyle.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text(TitleFormatter.displayTitle(event))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    verbatim:
                        "\(event.start.formatted(.dateTime.weekday(.wide).day().month(.wide))) · \(EventTimeText.range(event))"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            DetailLine(systemImage: "circle.fill", tint: Color(hex: event.calendarColorHex)) {
                Text(event.calendarTitle)
            }
            if !event.isAllDay, model.settings.showClocksInEventDetails {
                OtherTimeZonesView(event: event, clocks: model.settings.worldClocks)
            }
            if let link {
                HStack(alignment: .center, spacing: PanelStyle.small) {
                    ProviderIconView(provider: link.provider, size: 14)
                    Button("Join \(link.provider.displayName)") { MeetingOpener.open(link) }
                        .buttonStyle(.link)
                        .font(.callout)
                }
            }
            if !event.rooms.isEmpty {
                DetailLine(systemImage: "door.left.hand.open", tint: .secondary) {
                    Text(event.rooms.joined(separator: ", ")).textSelection(.enabled)
                }
            }
            if let location = displayLocation(link: link) {
                DetailLine(systemImage: "mappin.and.ellipse", tint: .secondary) {
                    Text(location).textSelection(.enabled)
                }
            }
            if let organizer = event.organizer, !organizer.isCurrentUser {
                DetailLine(systemImage: "person.crop.circle", tint: .secondary) {
                    Text("Organized by \(organizer.displayName)")
                }
            }
            if !event.people.isEmpty {
                ParticipantsView(people: event.people)
            }

            EventActionsRow(model: model, event: event)

            if let notes = NotesCleaner.clean(event.notes) {
                Divider()
                ScrollView {
                    Text(notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(PanelStyle.inset)
        .frame(width: 300, alignment: .leading)
    }

    /// The location field often just repeats the meeting URL; only show it when it adds something.
    private func displayLocation(link: MeetingLink?) -> String? {
        guard let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty else {
            return nil
        }
        if let link, location.contains(link.webURL.host ?? "\u{0}") {
            return nil
        }
        return location
    }
}

private struct DetailLine<Content: View>: View {
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PanelStyle.small) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 14)
            content.font(.callout)
        }
    }
}

/// Who's invited and how they answered, most relevant first, capped to keep the card short.
private struct ParticipantsView: View {
    let people: [Attendee]
    private let limit = 8

    var body: some View {
        let sorted = people.sorted { rank($0) < rank($1) }
        VStack(alignment: .leading, spacing: PanelStyle.tight) {
            Text(summary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(sorted.prefix(limit).enumerated()), id: \.offset) { _, person in
                HStack(spacing: PanelStyle.small) {
                    Image(systemName: icon(for: person.status))
                        .font(.caption)
                        .foregroundStyle(color(for: person.status))
                        .frame(width: 14)
                    Text(person.isCurrentUser ? String(localized: "\(person.displayName) (you)") : person.displayName)
                        .font(.callout)
                        .lineLimit(1)
                }
                .help(person.email ?? person.displayName)
            }
            if sorted.count > limit {
                Text("+\(sorted.count - limit) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summary: String {
        let accepted = people.filter { $0.status == .accepted }.count
        return String(localized: "\(people.count) guests · \(accepted) yes")
    }

    private func rank(_ person: Attendee) -> Int {
        if person.isOrganizer { return 0 }
        if person.isCurrentUser { return 1 }
        switch person.status {
        case .accepted: return 2
        case .tentative: return 3
        case .pending, .unknown: return 4
        case .declined: return 5
        }
    }

    private func icon(for status: ParticipationStatus) -> String {
        switch status {
        case .accepted: "checkmark.circle.fill"
        case .tentative: "questionmark.circle.fill"
        case .declined: "xmark.circle.fill"
        case .pending, .unknown: "circle.dashed"
        }
    }

    private func color(for status: ParticipationStatus) -> Color {
        switch status {
        case .accepted: .green
        case .tentative: .orange
        case .declined: .red
        case .pending, .unknown: .secondary
        }
    }
}

/// Card footer: Skip on the left, one primary action on the right. Answering and opening both go to
/// the same place, so there's a single button whose label says which it is.
struct EventActionsRow: View {
    let model: AppModel
    let event: CalendarEvent

    var body: some View {
        let destination = model.eventDestinationName(event)
        VStack(alignment: .leading, spacing: PanelStyle.small) {
            if !event.needsResponse, event.myStatus != .unknown {
                RSVPStatusLine(event: event)
            }
            Divider()
            HStack(spacing: PanelStyle.small) {
                if event.start > model.now {
                    SkipButton(model: model, event: event, showsLabel: true)
                }
                Spacer(minLength: 0)
                if event.needsResponse {
                    Button {
                        model.openEvent(event)
                    } label: {
                        Label(String(localized: "Answer in \(destination)"), systemImage: "arrow.up.forward")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("You haven't answered this invitation yet")
                } else {
                    Button {
                        model.openEvent(event)
                    } label: {
                        Label(String(localized: "Open in \(destination)"), systemImage: "arrow.up.forward")
                    }
                }
            }
            .controlSize(.small)
        }
    }
}

/// The meeting's time in each configured world clock, so "4 PM here" is also "9 PM in London".
/// Clocks on the Mac's own time zone are left out.
private struct OtherTimeZonesView: View {
    let event: CalendarEvent
    let clocks: [WorldClock]

    var body: some View {
        let others = clocks.filter {
            $0.timeZone.secondsFromGMT(for: event.start) != TimeZone.current.secondsFromGMT(for: event.start)
        }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: PanelStyle.tight) {
                ForEach(others) { clock in
                    let isDay = TimeZoneMath.isDaytime(in: clock.timeZone, at: event.start)
                    HStack(alignment: .firstTextBaseline, spacing: PanelStyle.small) {
                        Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
                            .font(.caption)
                            .foregroundStyle(isDay ? Color.orange : Color.indigo)
                            .frame(width: 14)
                        Text(clock.name)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: PanelStyle.small)
                        Text(verbatim: EventTimeText.range(event, in: clock.timeZone))
                            .monospacedDigit()
                        if let day = dayNote(in: clock.timeZone) {
                            Text(verbatim: "· \(day)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                }
            }
        }
    }

    /// "tomorrow" / "yesterday" when the meeting falls on another calendar day over there.
    private func dayNote(in zone: TimeZone) -> String? {
        switch TimeZoneMath.dayDifference(in: zone, at: event.start) {
        case 1: String(localized: "tomorrow")
        case -1: String(localized: "yesterday")
        default: nil
        }
    }
}
