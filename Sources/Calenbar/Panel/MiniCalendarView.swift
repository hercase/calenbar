import SwiftUI

/// Collapsible month grid. The header row toggles it (saved in settings);
/// when open it shows month navigation, dots on days with events, and selects a day for the list.
struct MiniCalendarView: View {
    let model: AppModel
    let state: PanelState

    private let calendar = Calendar.current

    private var isExpanded: Bool { model.settings.showMonthCalendar }

    var body: some View {
        VStack(spacing: PanelStyle.small) {
            header
            if isExpanded {
                grid
            }
        }
        .padding(.horizontal, PanelStyle.inset)
        .padding(.vertical, PanelStyle.medium)
    }

    private var header: some View {
        HStack(spacing: PanelStyle.tight) {
            Button {
                // No SwiftUI animation: the popover already animates its resize, and both together stutter.
                model.settings.showMonthCalendar.toggle()
            } label: {
                HStack(spacing: PanelStyle.tight + 2) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Text(state.displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.subheadline.weight(.semibold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? String(localized: "Hide calendar") : String(localized: "Show calendar"))
            .accessibilityLabel(isExpanded ? String(localized: "Hide calendar") : String(localized: "Show calendar"))

            Spacer(minLength: 0)

            if isExpanded {
                if showsTodayButton {
                    Button("Today") { state.resetToToday() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                IconButton(systemImage: "chevron.left", label: "Previous month") { shiftMonth(-1) }
                IconButton(systemImage: "chevron.right", label: "Next month") { shiftMonth(1) }
            }
        }
        .frame(height: PanelStyle.iconHitSize)
    }

    private var showsTodayButton: Bool {
        !calendar.isDate(state.displayedMonth, equalTo: Date(), toGranularity: .month)
            || !calendar.isDateInToday(state.selectedDay)
    }

    private var grid: some View {
        // Computed once per render: it queries EventKit, so it must not run per cell.
        let marked = markedDays
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        let showsWeeks = model.settings.showWeekNumbers
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: showsWeeks ? 8 : 7)
        return LazyVGrid(columns: columns, spacing: PanelStyle.tight) {
            if showsWeeks {
                Color.clear.frame(height: 18)
            }
            // Indexed: symbols repeat (T, S), and duplicate ids make SwiftUI drop cells.
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(height: 18)
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                if showsWeeks, let first = week.first {
                    let number = calendar.component(.weekOfYear, from: first)
                    Text(verbatim: "\(number)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .accessibilityLabel(String(localized: "Week \(number)"))
                }
                ForEach(week, id: \.self) { day in
                    let start = calendar.startOfDay(for: day)
                    DayCell(
                        day: day,
                        isInMonth: calendar.isDate(day, equalTo: state.displayedMonth, toGranularity: .month),
                        isToday: calendar.isDateInToday(day),
                        isSelected: calendar.isDate(day, inSameDayAs: state.selectedDay),
                        eventCount: marked.counts[start] ?? 0,
                        isDayOff: marked.off.contains(start)
                    ) {
                        state.selectedDay = start
                    }
                }
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let month = calendar.date(byAdding: .month, value: delta, to: state.displayedMonth) {
            state.displayedMonth = month
        }
    }

    /// Short weekday symbols, rotated to start on the user's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Only the weeks the displayed month spans (4–6), to keep the grid short.
    private var days: [Date] {
        let weekday = calendar.component(.weekday, from: state.displayedMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: state.displayedMonth)?.count ?? 31
        let cells = Int((Double(leading + daysInMonth) / 7).rounded(.up)) * 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: state.displayedMonth) else { return [] }
        return (0..<cells).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// How many timed events each day has (one to three dots), and days that are time off or a
    /// holiday (tinted). A week of vacation tints every day it covers.
    private var markedDays: (counts: [Date: Int], off: Set<Date>) {
        let days = days
        guard let first = days.first, let last = days.last,
            let end = calendar.date(byAdding: .day, value: 1, to: last)
        else { return ([:], []) }
        let events = model.settings.eventFilter.apply(model.calendar.events(from: first, to: end), for: .list)
        var off: Set<Date> = []
        let holidayCalendars = model.holidayCalendarIDs
        for event in events where event.dayOff(holidayCalendars: holidayCalendars) != nil {
            var day = calendar.startOfDay(for: max(event.start, first))
            while day < min(event.end, end) {
                off.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        var counts: [Date: Int] = [:]
        for event in events where !event.isAllDay {
            counts[calendar.startOfDay(for: event.start), default: 0] += 1
        }
        return (counts, off)
    }
}

private struct DayCell: View {
    let day: Date
    let isInMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    /// Timed events that day; the fill behind the number darkens in three steps (1–2, 3–4, 5+).
    let eventCount: Int
    let isDayOff: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            // The heat-map convention: a soft fill behind the number, stronger the busier the day, in one
            // hue. Today is the solid version of the same hue; the selected day is a ring; a day off is
            // written in the accent colour, the way printed calendars mark holidays in red.
            Text(day.formatted(.dateTime.day()))
                .font(.subheadline.weight(isToday || isDayOff ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(foreground)
                .frame(width: 24, height: 24)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    } else {
                        if let load = loadOpacity {
                            Circle().fill(Color.accentColor.opacity(load))
                        }
                        if isSelected {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var dayName: String { day.formatted(date: .complete, time: .omitted) }

    /// Three steps of the same hue: light, busy, packed. Nil leaves the cell plain.
    private var loadOpacity: Double? {
        switch eventCount {
        case ...0: nil
        case ...2: 0.10
        case ...4: 0.22
        default: 0.38
        }
    }

    private var accessibilityText: String {
        if isDayOff {
            return String(localized: "\(dayName), day off")
        }
        return eventCount > 0 ? String(localized: "\(dayName), \(eventCount) events") : dayName
    }

    private var foreground: Color {
        if isToday {
            return .white
        }
        if isDayOff {
            return isInMonth ? .accentColor : .accentColor.opacity(0.5)
        }
        return isInMonth ? .primary : .secondary.opacity(0.5)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}
