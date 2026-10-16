import CalenbarCore
import SwiftUI

/// Card shown next to a hovered event: calendar, meeting, location and description.
struct EventDetailView: View {
    let model: AppModel
    let event: CalendarEvent

    var body: some View {
        let link = event.meetingLink
        let location = event.displayLocation
        VStack(alignment: .leading, spacing: PanelStyle.medium) {
            // Header: what, which calendar.
            VStack(alignment: .leading, spacing: PanelStyle.tight) {
                Text(TitleFormatter.displayTitle(event))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: event.calendarColorHex))
                        .frame(width: 7, height: 7)
                    Text(event.calendarTitle)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // When: date, the time as the key fact, then the same moment elsewhere.
            VStack(alignment: .leading, spacing: PanelStyle.tight) {
                Text(event.start.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: PanelStyle.small) {
                    Text(EventTimeText.range(event))
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                    if let relative = EventTimeText.relative(event, now: model.now) {
                        Text(relative)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if !event.isAllDay, model.settings.showClocksInEventDetails {
                    OtherTimeZonesView(event: event, clocks: model.settings.worldClocks)
                        .padding(.top, PanelStyle.tight)
                }
            }

            if let link {
                Divider()
                Button {
                    MeetingOpener.open(link, eventKey: event.key)
                } label: {
                    HStack(spacing: 6) {
                        ProviderIconView(provider: link.provider, size: 16)
                        Text("Join \(link.provider.displayName)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if !event.rooms.isEmpty || location != nil || !event.people.isEmpty {
                Divider()
            }
            if !event.rooms.isEmpty || location != nil {
                VStack(alignment: .leading, spacing: PanelStyle.tight) {
                    if !event.rooms.isEmpty {
                        DetailLine(systemImage: "door.left.hand.open") {
                            Text(event.rooms.joined(separator: ", ")).textSelection(.enabled)
                        }
                    }
                    if let location {
                        DetailLine(systemImage: "mappin.and.ellipse") {
                            Text(location).textSelection(.enabled)
                        }
                    }
                }
            }

            if !event.people.isEmpty {
                ParticipantsView(people: event.people)
            }

            Divider()
            EventActionsRow(model: model, event: event, hasPrimaryJoin: link != nil)

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
}

private struct DetailLine<Content: View>: View {
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PanelStyle.small) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            content.font(.callout)
        }
    }
}

/// Who's invited and how they answered: a small section label, the organizer first, then the rest,
/// capped to keep the card short.
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
                    if person.isOrganizer {
                        Text("Organizer")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                }
                .help(person.email ?? person.displayName)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(person))
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
        return String(localized: "\(people.count) guests · \(accepted) accepted")
    }

    private func accessibilityLabel(_ person: Attendee) -> String {
        var parts = [person.displayName, statusName(person.status)]
        if person.isOrganizer {
            parts.append(String(localized: "Organizer"))
        }
        return parts.joined(separator: ", ")
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

    private func statusName(_ status: ParticipationStatus) -> String {
        switch status {
        case .accepted: String(localized: "accepted")
        case .tentative: String(localized: "maybe")
        case .declined: String(localized: "declined")
        case .pending, .unknown: String(localized: "not answered")
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
    /// When the card already has a prominent Join, answering/opening steps back to a plain button.
    var hasPrimaryJoin = false

    var body: some View {
        let destination = model.eventDestinationName(event)
        VStack(alignment: .leading, spacing: PanelStyle.small) {
            if !event.needsResponse, event.myStatus != .unknown {
                RSVPStatusLine(event: event)
            }
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
                    .tint(hasPrimaryJoin ? .secondary : .accentColor)
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
/// Clocks on the Mac's own time zone are left out. Laid out as a grid so the times line up.
private struct OtherTimeZonesView: View {
    let event: CalendarEvent
    let clocks: [WorldClock]

    var body: some View {
        let others = clocks.filter { TimeZoneMath.offset(of: $0.timeZone, at: event.start) != 0 }
        if !others.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: PanelStyle.small, verticalSpacing: PanelStyle.tight) {
                ForEach(others) { clock in
                    let isDay = TimeZoneMath.isDaytime(in: clock.timeZone, at: event.start)
                    GridRow(alignment: .firstTextBaseline) {
                        Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
                            .font(.caption)
                            .foregroundStyle(isDay ? Color.orange : Color.indigo)
                            .frame(width: 14)
                        Text(clock.name)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(verbatim: EventTimeText.range(event, in: clock.timeZone))
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                        Text(dayNote(in: clock.timeZone) ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .accessibilityElement(children: .combine)
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
