import CalenbarCore
import SwiftUI

struct WorldClockSettings: View {
    @Bindable var settings: AppSettings
    @Bindable var uiState: SettingsUIState
    let clock: MinuteClock

    var body: some View {
        Form {
            Section {
                if settings.worldClocks.isEmpty {
                    VStack(spacing: PanelStyle.small) {
                        Image(systemName: "globe")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No world clocks yet").font(.headline)
                        Text("Add the cities you work with to see their time in the panel and in each meeting.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PanelStyle.large)
                } else {
                    let count = settings.worldClocks.count
                    ForEach(Array($settings.worldClocks.enumerated()), id: \.element.id) { index, $clock in
                        // Read the id first: reading `clock` inside removeAll would overlap the write to the
                        // same array and trip Swift's exclusivity check (a crash, not a warning).
                        let id = clock.id
                        ClockRow(
                            clock: $clock,
                            now: self.clock.now,
                            canMoveUp: index > 0,
                            canMoveDown: index < count - 1,
                            move: { delta in settings.worldClocks.swapAt(index, index + delta) },
                            remove: { settings.worldClocks.removeAll { $0.id == id } }
                        )
                    }
                    .onMove { settings.worldClocks.move(fromOffsets: $0, toOffset: $1) }
                }
            } header: {
                Text("Clocks")
            } footer: {
                HStack {
                    let limit = AppSettings.maxWorldClocks
                    Text(
                        uiState.clockNote
                            ?? String(localized: "Up to \(limit) clocks, in the order of the list; the arrows reorder them.")
                    )
                    .font(.caption)
                    .foregroundStyle(uiState.clockNote == nil ? .secondary : .primary)
                    Spacer()
                    Button("Add Clock…") {
                        uiState.clockNote = nil
                        uiState.isAddingClock = true
                    }
                    .disabled(settings.worldClocks.count >= AppSettings.maxWorldClocks)
                    .popover(isPresented: $uiState.isAddingClock, arrowEdge: .bottom) {
                        let existing = Set(settings.worldClocks.map(\.timeZoneID))
                        ClockPicker(search: uiState.citySearch, existing: existing) { identifier, name in
                            let added = settings.addWorldClock(timeZoneID: identifier, name: name)
                            // A city can resolve to a zone already in the list; say so instead of closing quietly.
                            uiState.clockNote =
                                added
                                ? nil
                                : String(localized: "\(name) is already in the list as the same time zone.")
                            uiState.citySearch.query = ""
                            uiState.isAddingClock = false
                        }
                    }
                }
            }
            Section("Show") {
                Toggle("In the panel", isOn: $settings.showClocksInPanel)
                Toggle("Meeting times in event details", isOn: $settings.showClocksInEventDetails)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ClockRow: View {
    @Binding var clock: WorldClock
    let now: Date
    let canMoveUp: Bool
    let canMoveDown: Bool
    let move: (_ delta: Int) -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: PanelStyle.medium) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $clock.name, prompt: Text("Name"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .font(.body.weight(.medium))
                    .help("Click to rename")
                Text(subtitle(at: now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Unusual, so it stands out a little: accent, not alarm. Only shown inside a month.
                if let change = clockChange(at: now) {
                    Label(change, systemImage: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(now.formatted(WorldClocksView.timeStyle(in: clock.timeZone)))
                    .monospacedDigit()
                if let day = WorldClocksView.dayNote(in: clock.timeZone, at: now) {
                    Text(day).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 2) {
                IconButton(systemImage: "chevron.up", label: String(localized: "Move up")) { move(-1) }
                    .disabled(!canMoveUp)
                    .opacity(canMoveUp ? 1 : 0.3)
                IconButton(systemImage: "chevron.down", label: String(localized: "Move down")) { move(1) }
                    .disabled(!canMoveDown)
                    .opacity(canMoveDown ? 1 : 0.3)
                IconButton(systemImage: "minus.circle.fill", label: String(localized: "Remove \(clock.name)"), action: remove)
            }
        }
    }

    /// "America/Los Angeles · PDT · UTC−7 · −4h": the zone, its short name, where it sits, and how far from you.
    private func subtitle(at now: Date) -> String {
        var parts = [clock.timeZoneID.replacingOccurrences(of: "_", with: " ")]
        if let abbreviation = TimeZoneFacts.abbreviation(of: clock.timeZone, at: now), !abbreviation.hasPrefix("GMT") {
            parts.append(abbreviation)
        }
        parts.append(TimeZoneFacts.utcOffsetText(of: clock.timeZone, at: now))
        parts.append(WorldClocksView.offsetText(of: clock.timeZone, at: now))
        return parts.joined(separator: " · ")
    }

    /// "From 1 Nov, −5h": what the distance becomes once that zone's clocks change. The fact that
    /// matters is the new offset; the mechanics (forward, back) don't need saying.
    private func clockChange(at now: Date) -> String? {
        guard let change = TimeZoneFacts.upcomingClockChange(in: clock.timeZone, at: now, within: 31) else { return nil }
        var style = Date.FormatStyle().month(.abbreviated).day()
        style.timeZone = clock.timeZone
        let when = change.date.formatted(style)
        let after = WorldClocksView.offsetText(of: clock.timeZone, at: change.date.addingTimeInterval(60))
        return String(localized: "From \(when), \(after)")
    }
}

/// "Add Clock…" popover: cities from Apple Maps first, then matching time zones (works offline).
private struct ClockPicker: View {
    @Bindable var search: CitySearch
    /// Time zones already in the list; shown with a checkmark and not selectable again.
    let existing: Set<String>
    let pick: (_ identifier: String, _ name: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.small) {
            TextField(
                "Search a city, e.g. San Diego or Madrid", text: $search.query,
                prompt: Text("Search a city, e.g. San Diego or Madrid")
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.leading)
            if search.query.count < 2 {
                hint("Type at least 2 letters")
            } else if search.cities.isEmpty && zones.isEmpty {
                hint("No matching places")
            } else {
                List {
                    if !search.cities.isEmpty {
                        Section("Cities") {
                            ForEach(search.cities) { city in
                                row(city.title, detail: city.subtitle) {
                                    Task {
                                        if let place = await search.resolve(city) {
                                            pick(place.timeZone.identifier, place.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !zones.isEmpty {
                        Section("Time zones") {
                            ForEach(zones, id: \.self) { identifier in
                                row(Self.cityName(identifier), detail: identifier, added: existing.contains(identifier)) {
                                    pick(identifier, Self.cityName(identifier))
                                }
                            }
                        }
                    }
                }
                .frame(height: 240)
                .overlay {
                    if search.isResolving {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .padding(PanelStyle.medium)
        .frame(width: 340)
        .multilineTextAlignment(.leading)
    }

    private func hint(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, PanelStyle.tight)
    }

    private func row(_ title: String, detail: String, added: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if added {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Already added")
                }
            }
            .padding(.horizontal, PanelStyle.tight + 2)
            .padding(.vertical, 3)
        }
        .buttonStyle(QuietButtonStyle())
        // The wash sits outside the text, so the names still line up with the search field.
        .padding(.horizontal, -(PanelStyle.tight + 2))
        .disabled(added)
    }

    /// An abbreviation the team uses ("ET", "CET") comes first, then identifiers containing the text.
    private var zones: [String] {
        guard search.query.count >= 2 else { return [] }
        var found: [String] = []
        if let alias = TimeZoneAliases.identifier(for: search.query) {
            found.append(alias)
        }
        let needle = search.query.replacingOccurrences(of: " ", with: "_").lowercased()
        let matches = TimeZone.knownTimeZoneIdentifiers.filter { $0.lowercased().contains(needle) && !found.contains($0) }
        return found + matches.prefix(10)
    }

    static func cityName(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }
}
