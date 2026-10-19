import CalenbarCore
import SwiftUI

struct WorldClockSettings: View {
    @Bindable var settings: AppSettings
    @Bindable var uiState: SettingsUIState

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
                    Text("Up to \(limit) clocks, in the order of the list; the arrows reorder them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Clock…") { uiState.isAddingClock = true }
                        .disabled(settings.worldClocks.count >= AppSettings.maxWorldClocks)
                        .popover(isPresented: $uiState.isAddingClock, arrowEdge: .bottom) {
                            let existing = Set(settings.worldClocks.map(\.timeZoneID))
                            ClockPicker(search: uiState.citySearch, existing: existing) { identifier, name in
                                settings.addWorldClock(timeZoneID: identifier, name: name)
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
    let canMoveUp: Bool
    let canMoveDown: Bool
    let move: (_ delta: Int) -> Void
    let remove: () -> Void

    var body: some View {
        let now = Date()
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
                if let change = clockChange(at: now) {
                    Label(change, systemImage: "clock.arrow.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
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

    /// "Clocks go back 1h on Nov 1": the thing that silently breaks next week's meeting times.
    private func clockChange(at now: Date) -> String? {
        guard let change = TimeZoneFacts.upcomingClockChange(in: clock.timeZone, at: now) else { return nil }
        let when = change.date.formatted(.dateTime.month(.abbreviated).day())
        let hours = abs(change.hourShift).formatted(.number.precision(.fractionLength(0...1)))
        return change.hourShift > 0
            ? String(localized: "Clocks go forward \(hours)h on \(when)")
            : String(localized: "Clocks go back \(hours)h on \(when)")
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
