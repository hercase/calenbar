import AppKit
import ServiceManagement

/// Starts Calenbar at login through a launchd agent that also relaunches it if it ever crashes
/// (KeepAlive on unsuccessful exit). Quitting from the panel exits cleanly and stays quit.
@MainActor
enum LoginLaunch {
    static let label = "com.hernancase.calenbar.agent"
    private static let plistName = "\(label).plist"
    private static let enabledOnceKey = "loginLaunchEnabledOnce"

    private static var agent: SMAppService { .agent(plistName: plistName) }

    static var isEnabled: Bool { agent.status == .enabled }

    /// True when this process was started by the launchd agent (so a crash will be recovered).
    static var isManagedByLaunchd: Bool {
        ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] == label
    }

    /// Turned on once by default: staying alive is the point of a menu bar calendar.
    static func enableOnFirstRun() {
        // Earlier builds used a plain login item; the agent replaces it.
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        }
        guard !UserDefaults.standard.bool(forKey: enabledOnceKey) else { return }
        UserDefaults.standard.set(true, forKey: enabledOnceKey)
        setEnabled(true)
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            try? agent.register()
        } else {
            // Unloading the agent stops the process it manages; reopen the app outside launchd first.
            if isManagedByLaunchd {
                relaunchDetached(bundlePath: Bundle.main.bundlePath)
            }
            try? agent.unregister()
        }
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
