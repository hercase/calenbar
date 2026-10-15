import AppKit
import CalenbarCore
import Observation

/// Checks GitHub Releases once a day for a newer version. Updates are installed by hand from the
/// release's DMG; this only tells the user one exists and takes them there.
@MainActor
@Observable
final class UpdateChecker {
    struct Release: Equatable {
        let version: AppVersion
        let pageURL: URL
    }

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/hercase/calenbar/releases/latest")
    private static let checkInterval: TimeInterval = 24 * 3_600

    /// Set when GitHub has a release newer than the running app.
    private(set) var available: Release?
    private(set) var lastCheck: Date?
    private(set) var isChecking = false

    @ObservationIgnored private var timer: Timer?

    var currentVersion: AppVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
    }

    func start() {
        Task { await check() }
        let timer = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.check() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func check() async {
        guard !isChecking, let url = Self.latestReleaseURL, let current = currentVersion else { return }
        isChecking = true
        defer {
            isChecking = false
            lastCheck = Date()
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let payload = try? JSONDecoder().decode(LatestRelease.self, from: data),
            let version = AppVersion(payload.tagName),
            let page = URL(string: payload.htmlURL)
        else { return }

        available = version.isNewer(than: current) ? Release(version: version, pageURL: page) : nil
    }

    func openReleasePage() {
        if let available {
            NSWorkspace.shared.open(available.pageURL)
        }
    }
}

/// The fields we need from GitHub's "latest release" API response.
private struct LatestRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
