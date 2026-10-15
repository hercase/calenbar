import MapKit
import Observation

/// City autocomplete backed by Apple Maps, so any town ("San Diego") can be added, not just the one
/// city each time zone is named after. Picking a result resolves its time zone.
@MainActor
@Observable
final class CitySearch: NSObject, MKLocalSearchCompleterDelegate {
    struct City: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        fileprivate let completion: MKLocalSearchCompletion
    }

    var query = "" {
        didSet { completer.queryFragment = query }
    }
    private(set) var cities: [City] = []
    private(set) var isResolving = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    /// Looks up the city's time zone. Nil when Maps can't tell (offline, or a non-place result).
    func resolve(_ city: City) async -> (name: String, timeZone: TimeZone)? {
        isResolving = true
        defer { isResolving = false }
        let request = MKLocalSearch.Request(completion: city.completion)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first,
            let zone = item.timeZone
        else { return nil }
        return (city.title, zone)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
            .filter { !$0.title.contains(where: \.isNumber) }  // skip street addresses
            .prefix(8)
            .map { City(id: "\($0.title)|\($0.subtitle)", title: $0.title, subtitle: $0.subtitle, completion: $0) }
        Task { @MainActor in self.cities = Array(results) }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.cities = [] }
    }
}
