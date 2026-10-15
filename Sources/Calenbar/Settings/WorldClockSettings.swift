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
                        Text("Add the cities you work with. They show at the bottom of the panel.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PanelStyle.large)
                } else {
                    ForEach($settings.worldClocks) { $clock in
                        ClockRow(clock: $clock) {
                            settings.worldClocks.removeAll { $0.id == clock.id }
                        }
                    }
                    .onMove { settings.worldClocks.move(fromOffsets: $0, toOffset: $1) }
                }
            } header: {
                Text("World Clocks")
            } footer: {
                HStack {
                    Text("Up to 3 clocks, shown at the bottom of the panel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Clock…") { uiState.isAddingClock = true }
                        .disabled(settings.worldClocks.count >= AppSettings.maxWorldClocks)
                        .popover(isPresented: $uiState.isAddingClock, arrowEdge: .bottom) {
                            ClockPicker(search: uiState.citySearch) { identifier, name in
                                settings.worldClocks.append(WorldClock(timeZoneID: identifier, name: name))
                                uiState.citySearch.query = ""
                                uiState.isAddingClock = false
                            }
                        }
                }
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
            Text(Date().formatted(Self.timeStyle(clock.timeZone)))
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
        return "\(zone) · \(InlineClocksView.offset(of: clock.timeZone, at: Date()))"
    }

    private static func timeStyle(_ zone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return style
    }
}

/// "Add Clock…" popover: cities from Apple Maps first, then matching time zones (works offline).
private struct ClockPicker: View {
    @Bindable var search: CitySearch
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
                                row(Self.cityName(identifier), detail: identifier) { pick(identifier, Self.cityName(identifier)) }
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

    private func row(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
