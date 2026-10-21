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
                        let items = FreeTime.agenda(
                            events: section.events, on: section.day, now: model.now, calendar: calendar,
                            includeFree: model.settings.showFreeTime)
                        ForEach(items) { item in
                            switch item {
                            case .free(let slot):
                                FreeTimeRow(model: model, state: state, slot: slot)
                            case .overlap(_, let group):
                                OverlapGroup(model: model, state: state, events: group)
                            case .event(let event):
                                EventRow(
                                    model: model, state: state, event: event, isHovered: state.hoveredEventID == event.id)
                            }
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
        let day: Date
        let title: String
        let events: [CalendarEvent]
    }

    private var sections: [Section] {
        let day = state.selectedDay
        if calendar.isDateInToday(day), let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) {
            return [
                Section(day: day, title: String(localized: "Today"), events: model.listEvents(on: day)),
                Section(day: tomorrow, title: String(localized: "Tomorrow"), events: model.listEvents(on: tomorrow)),
            ]
        }
        let title = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return [Section(day: day, title: title, events: model.listEvents(on: day))]
    }
}

/// Meetings that share a slot sit in one container, so the clash is visible without deciding which one matters.
private struct OverlapGroup: View {
    let model: AppModel
    let state: PanelState
    let events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.tight - 2) {
            Label("At the same time", systemImage: "arrow.left.arrow.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, PanelStyle.tight + 2)
                .padding(.top, PanelStyle.tight)
            ForEach(events) { event in
                EventRow(model: model, state: state, event: event, isHovered: state.hoveredEventID == event.id)
            }
        }
        .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: PanelStyle.rowCornerRadius + 2))
    }
}

/// One line for a free stretch. The words are the preview; the line only marks the place.
/// The stretch you're in uses the accent color, the same mark as today. Actions wait for a hover or a click.
private struct FreeTimeRow: View {
    let model: AppModel
    let state: PanelState
    let slot: FreeTime.Slot

    var body: some View {
        let isHovered = state.hoveredFreeID == slot.id
        let isRevealed = state.revealedFreeID == slot.id
        VStack(alignment: .leading, spacing: PanelStyle.tight) {
            HStack(spacing: PanelStyle.small) {
                hairline(isNow: isOpenNow, isActive: isHovered || isRevealed)
                Text(copy)
                    .font(.caption)
                    .foregroundStyle(isOpenNow || slot.isLong ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                    .lineLimit(1)
                    .fixedSize()
                hairline(isNow: isOpenNow, isActive: isHovered || isRevealed)
            }
            .contentShape(Rectangle())
            .onTapGesture { state.toggleFree(slot.id) }
            if isRevealed, slot.canBook {
                FreeTimeActions(model: model, state: state, slot: slot)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, PanelStyle.tight + 2)
        .frame(minHeight: 22)
        .onHover { state.setHoveringFree($0, id: slot.id) }
        .focusable(true, interactions: .activate)
        .onKeyPress(.return) {
            state.toggleFree(slot.id)
            return .handled
        }
        .onKeyPress(.space) {
            state.toggleFree(slot.id)
            return .handled
        }
        .accessibilityElement(children: isRevealed ? .contain : .ignore)
        .accessibilityLabel(isOpenNow ? String(localized: "Now, \(copy)") : copy)
        .accessibilityAddTraits(slot.canBook ? .isButton : [])
    }

    /// The stretch that is open right now. Future gaps say how long they are; this one says how much is left.
    private var isOpenNow: Bool {
        guard slot.canBook else { return false }
        if case .until = slot.label { return true }
        return false
    }

    private var copy: String {
        switch slot.label {
        case .until(let date):
            let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened))
            if slot.canBook {
                // Same rounding as the next event's "in 24m". Counting from the next whole minute,
                // which is where a block starts, made the two labels disagree.
                let left = TitleFormatter.compactDuration(slot.end.timeIntervalSince(model.now))
                return String(localized: "\(left) free until \(time)")
            }
            return String(localized: "Free until \(time)")
        case .duration(let seconds):
            return String(localized: "\(TitleFormatter.compactDuration(seconds)) free")
        }
    }

    private func hairline(isNow: Bool, isActive: Bool) -> some View {
        Rectangle()
            .fill(isNow ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(isActive ? 0.5 : 0.2)))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

}

private struct EventRow: View {
    let model: AppModel
    let state: PanelState
    let event: CalendarEvent
    /// Passed in rather than read from `state`, so a hover change re-renders two rows, not all of them.
    let isHovered: Bool

    var body: some View {
        let isPast = event.end <= model.now
        let isSkipped = model.isSkipped(event)
        let link = event.meetingLink

        HStack(spacing: PanelStyle.small) {
            CalendarColorBar(colorHex: event.calendarColorHex, needsResponse: event.needsResponse)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if isSkipped {
                        Image(systemName: "eye.slash").font(.caption2)
                    }
                    if let kind = event.dayOff(holidayCalendars: model.holidayCalendarIDs) {
                        Image(systemName: kind == .holiday ? "sun.max.fill" : "beach.umbrella.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
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
            // Countdown and Skip share one slot so nothing shifts when the pointer arrives.
            ZStack(alignment: .trailing) {
                if let relative = EventTimeText.relative(event, now: model.now) {
                    Text(relative)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .opacity(isHovered && !isPast ? 0 : 1)
                }
                if !isPast {
                    SkipButton(model: model, event: event)
                        .opacity(isHovered ? 1 : 0)
                        .accessibilityHidden(!isHovered)
                }
            }
            if let link, !isPast {
                Button {
                    MeetingOpener.open(link, eventKey: event.key)
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
        // Double-click first so a single click waits for it; Return and Space work like a click.
        .onTapGesture(count: 2) { model.openEvent(event) }
        .onTapGesture { state.toggleDetail(eventID: event.id) }
        .focusable(true, interactions: .activate)
        .onKeyPress(.return) {
            state.toggleDetail(eventID: event.id)
            return .handled
        }
        .onKeyPress(.space) {
            state.toggleDetail(eventID: event.id)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel(isPast: isPast, isSkipped: isSkipped))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { state.toggleDetail(eventID: event.id) }
        .popover(
            isPresented: Binding(
                get: { state.detailEventID == event.id },
                set: { if !$0 { state.detailDismissed(eventID: event.id) } }
            ),
            arrowEdge: .leading
        ) {
            EventDetailView(model: model, event: event)
                .onHover { state.setHoveringDetail($0) }
        }
        .contextMenu { EventContextMenu(model: model, event: event) }
    }

    /// One sentence for VoiceOver: title, time, countdown and status.
    private func accessibilityLabel(isPast: Bool, isSkipped: Bool) -> String {
        var parts = [TitleFormatter.displayTitle(event), EventTimeText.range(event)]
        if let relative = EventTimeText.relative(event, now: model.now) {
            parts.append(relative)
        }
        if event.needsResponse, !isPast {
            parts.append(String(localized: "Not answered"))
        }
        if isSkipped {
            parts.append(String(localized: "Skipped"))
        }
        if let kind = event.dayOff(holidayCalendars: model.holidayCalendarIDs) {
            parts.append(kind == .holiday ? String(localized: "Holiday") : String(localized: "Time off"))
        }
        return parts.joined(separator: ", ")
    }
}

/// Skip = act as if this occurrence didn't exist: gone from the menu bar, no notification or alert.
/// It stays in the list, dimmed, so it can be brought back. The same control everywhere: an icon in
/// rows and the hero, with its label in the detail card.
struct SkipButton: View {
    let model: AppModel
    let event: CalendarEvent
    var showsLabel = false

    var body: some View {
        let isSkipped = model.isSkipped(event)
        let title = isSkipped ? String(localized: "Unskip") : String(localized: "Skip")
        let help =
            isSkipped
            ? String(localized: "Bring this event back") : String(localized: "Skip: hide from the menu bar and don’t alert")
        let symbol = isSkipped ? "eye" : "eye.slash"
        if showsLabel {
            Button {
                model.settings.toggleSkipped(event)
            } label: {
                Label(title, systemImage: symbol)
            }
            .buttonStyle(.bordered)
            .fixedSize()
            .help(help)
        } else {
            IconButton(systemImage: symbol, label: help) {
                model.settings.toggleSkipped(event)
            }
        }
    }
}
