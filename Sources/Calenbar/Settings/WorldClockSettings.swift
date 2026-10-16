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
                    ForEach($settings.worldClocks) { $clock in
                        // Read the id first: reading `clock` inside removeAll would overlap the write to the
                        // same array and trip Swift's exclusivity check (a crash, not a warning).
                        let id = clock.id
                        ClockRow(clock: $clock) {
                            settings.worldClocks.removeAll { $0.id == id }
                        }
                    }
                    .onMove { settings.worldClocks.move(fromOffsets: $0, toOffset: $1) }
                }
            } header: {
                Text("Clocks")
            } footer: {
                HStack {
                    let limit = AppSettings.maxWorldClocks
                    Text("Up to \(limit) clocks.")
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
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Date().formatted(WorldClocksView.timeStyle(in: clock.timeZone)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove \(clock.name)")
            .accessibilityLabel("Remove \(clock.name)")
        }
    }

    private var subtitle: String {
        let zone = clock.timeZoneID.replacingOccurrences(of: "_", with: " ")
        return "\(zone) · \(WorldClocksView.offsetText(of: clock.timeZone, at: Date()))"
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

    private var zones: [String] {
        guard search.query.count >= 2 else { return [] }
        let needle = search.query.replacingOccurrences(of: " ", with: "_").lowercased()
        return TimeZone.knownTimeZoneIdentifiers.filter { $0.lowercased().contains(needle) }.prefix(10).map { $0 }
    }

    static func cityName(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }
}
