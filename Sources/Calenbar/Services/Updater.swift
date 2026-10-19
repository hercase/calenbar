import AppKit
import Observation
import Sparkle

/// Keeps the app current through Sparkle: checks the appcast once a day, downloads new versions in
/// the background, and installs them on relaunch. The feed URL and the EdDSA public key that every
/// download is verified against live in Info.plist (`SUFeedURL`, `SUPublicEDKey`).
@MainActor
@Observable
final class Updater: NSObject, SPUUpdaterDelegate {
    struct Pending: Equatable {
        let version: String
        /// Downloaded and verified; installing only needs a relaunch.
        var isReadyToInstall: Bool
    }

    /// A newer version Sparkle knows about, until it is installed.
    private(set) var pending: Pending?
    /// False while a check or install is in progress (or before the updater started).
    private(set) var canCheck = false
    private(set) var lastCheck: Date?

    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// Updates only make sense for an installed bundle, not for `swift run` or a copy on a disk image.
    var isAvailable: Bool { controller != nil }

    /// Mirrors Sparkle's setting so SwiftUI sees changes (the controller itself isn't observable).
    var automaticallyDownloads = false {
        didSet { controller?.updater.automaticallyDownloadsUpdates = automaticallyDownloads }
    }

    func start() {
        guard Bundle.main.bundleIdentifier != nil, !InstallLocation.isTemporary else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        let options: NSKeyValueObservingOptions = [.initial, .new]
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: options) { [weak self] _, change in
            let value = change.newValue ?? false
            MainActor.assumeIsolated { self?.canCheck = value }
        }
        controller.startUpdater()
        automaticallyDownloads = controller.updater.automaticallyDownloadsUpdates
        lastCheck = controller.updater.lastUpdateCheckDate
    }

    /// User-initiated check with Sparkle's own windows; also the way to install a downloaded update.
    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        pending = Pending(version: item.displayVersionString, isReadyToInstall: false)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        pending = Pending(version: item.displayVersionString, isReadyToInstall: true)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        pending = nil
    }

    /// "Skip This Version" in Sparkle's dialog: stop badging the icon and the menus for it.
    func updater(
        _ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice, forUpdate item: SUAppcastItem, state: SPUUserUpdateState
    ) {
        if choice == .skip {
            pending = nil
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        pending = nil
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        lastCheck = updater.lastUpdateCheckDate
    }
}
