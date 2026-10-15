import CalenbarCore
import SwiftUI

/// Today + Tomorrow, or the single day picked in the mini calendar.
struct EventListView: View {
    let model: AppModel
    let state: PanelState

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PanelStyle.medium) {
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: PanelStyle.tight - 2) {
                        SectionHeader(section.title)
                            .padding(.bottom, PanelStyle.tight - 2)
                        if section.events.isEmpty {
                            Text("No events")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, PanelStyle.tight)
                        }
                        ForEach(section.events) { event in
                            EventRow(model: model, state: state, event: event)
                        }
                    }
                }
            }
            // Rows extend into the inset so their hover background lines up with the section text.
            .padding(.horizontal, PanelStyle.inset - PanelStyle.tight - 2)
            .padding(.vertical, PanelStyle.small + 2)
        }
        .frame(maxHeight: 340)
        .fixedSize(horizontal: false, vertical: true)
    }

    private struct Section {
        let title: String
        let events: [CalendarEvent]
    }

    private var sections: [Section] {
        let day = state.selectedDay
        if calendar.isDateInToday(day), let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) {
            return [
                Section(title: "Today", events: model.listEvents(on: day)),
                Section(title: "Tomorrow", events: model.listEvents(on: tomorrow)),
            ]
        }
        let title = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return [Section(title: title, events: model.listEvents(on: day))]
    }
}

private struct EventRow: View {
    let model: AppModel
    let state: PanelState
    let event: CalendarEvent

    var body: some View {
        let isPast = event.end <= model.now
        let isSkipped = model.isSkipped(event)
        let isHovered = state.hoveredEventID == event.id
        let link = event.meetingLink

        HStack(spacing: PanelStyle.small) {
            CalendarColorBar(colorHex: event.calendarColorHex, needsResponse: event.needsResponse)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if isSkipped {
                        Image(systemName: "eye.slash").font(.caption2)
                    }
                    Text(TitleFormatter.displayTitle(event)).lineLimit(1)
                }
                HStack(spacing: 0) {
                    Text(EventTimeText.range(event))
                        .foregroundStyle(.secondary)
                    if event.needsResponse, !isPast {
                        Text(" · Not answered")
                            .foregroundStyle(.orange.opacity(0.9))
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer(minLength: PanelStyle.tight)
            // On hover the countdown makes room for the labeled Skip button.
            if !(isHovered && !isPast), let relative = EventTimeText.relative(event, now: model.now) {
                Text(relative)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if !isPast, isHovered {
                SkipButton(model: model, event: event)
            }
            if let link, !isPast {
                Button {
                    MeetingOpener.open(link)
                } label: {
                    ProviderIconView(provider: link.provider, size: 18)
                        .frame(width: PanelStyle.iconHitSize, height: PanelStyle.iconHitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Join \(link.provider.displayName)")
                .accessibilityLabel("Join \(link.provider.displayName)")
            }
        }
        .padding(.vertical, PanelStyle.tight + 1)
        .padding(.horizontal, PanelStyle.tight + 2)
        .frame(minHeight: 40)
        .background(
            isHovered ? Color.primary.opacity(0.07) : .clear,
            in: RoundedRectangle(cornerRadius: PanelStyle.rowCornerRadius)
        )
        .opacity(isPast || isSkipped ? 0.45 : 1)
        .contentShape(Rectangle())
        .onHover { state.setHovering($0, eventID: event.id) }
        .popover(
            isPresented: Binding(
                get: { state.detailEventID == event.id },
                set: { if !$0, state.detailEventID == event.id { state.detailEventID = nil } }
            ),
            arrowEdge: .leading
        ) {
            EventDetailView(model: model, event: event)
                .onHover { state.setHoveringDetail($0) }
        }
        .onTapGesture(count: 2) { model.openEvent(event) }
        .contextMenu { EventContextMenu(model: model, event: event) }
    }
}

/// Skip = act as if this occurrence didn't exist: gone from the menu bar, no notification or alert.
/// It stays in the list, dimmed, so it can be brought back. Shown with a label on hover.
struct SkipButton: View {
    let model: AppModel
    let event: CalendarEvent

    var body: some View {
        let isSkipped = model.isSkipped(event)
        let help = isSkipped ? "Bring this event back" : "Skip: hide from the menu bar and don't alert"
        Button {
            model.settings.toggleSkipped(event)
        } label: {
            Label(isSkipped ? "Unskip" : "Skip", systemImage: isSkipped ? "eye" : "eye.slash")
                .font(.caption.weight(.medium))
                .padding(.horizontal, PanelStyle.small)
                .frame(height: 22)
                .background(Color.primary.opacity(0.08), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .help(help)
        .accessibilityLabel(help)
    }
}
