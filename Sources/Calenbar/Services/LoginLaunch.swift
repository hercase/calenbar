import AppKit
import ServiceManagement

/// Starts Calenbar at login as a standard login item (SMAppService.mainApp).
@MainActor
enum LoginLaunch {
    /// Builds up to 0.8.0 registered a launchd agent instead. launchd pins an agent to the code
    /// hash it saw at registration, so after an update it refused to spawn (EX_CONFIG) and the app
    /// stopped starting at login. It is only unregistered now.
    static let legacyLabel = "com.hernancase.calenbar.agent"
    private static let legacyAgent = SMAppService.agent(plistName: "\(legacyLabel).plist")
    private static let enabledOnceKey = "loginLaunchEnabledOnce"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// True when this process was started by the legacy launchd agent.
    static var isManagedByLaunchd: Bool {
        ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] == legacyLabel
    }

    /// Turned on once by default: staying alive is the point of a menu bar calendar.
    static func enableOnFirstRun() {
        // Whoever had the agent registered had launch at login on: carry that over.
        if legacyAgent.status != .notRegistered {
            removeLegacyAgent()
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: enabledOnceKey)
            return
        }
        guard !UserDefaults.standard.bool(forKey: enabledOnceKey) else { return }
        UserDefaults.standard.set(true, forKey: enabledOnceKey)
        setEnabled(true)
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    private static func removeLegacyAgent() {
        // Unloading the agent stops the process it manages; reopen the app outside launchd first.
        if isManagedByLaunchd {
            relaunchDetached(bundlePath: Bundle.main.bundlePath)
        }
        try? legacyAgent.unregister()
    }

    /// Opens the app at `bundlePath` a second later, from outside this process, so it starts after we
    /// are gone (used when launchd would otherwise kill it, and when handing over to a moved copy).
    static func relaunchDetached(bundlePath: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open -n \"$0\"", bundlePath]
        try? process.run()
    }
}

/// Makes sure only one Calenbar runs. The launchd-managed copy wins, since it is crash-protected.
@MainActor
enum SingleInstance {
    /// Returns false when this process should exit because another copy already runs.
    static func claim() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return true }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        guard !others.isEmpty else { return true }
        if LoginLaunch.isManagedByLaunchd {
            others.forEach { $0.terminate() }
            return true
        }
        return false
    }
}
