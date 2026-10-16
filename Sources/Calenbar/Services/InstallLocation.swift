import AppKit

/// Makes sure the app runs from a permanent, writable place before it registers a login agent or
/// installs updates. People who open Calenbar straight from the mounted disk image would otherwise
/// get a login item pointing into an ejected volume.
@MainActor
enum InstallLocation {
    /// True when running from a disk image or from Gatekeeper's app-translocation folder.
    static var isTemporary: Bool {
        let path = Bundle.main.bundlePath
        if path.contains("/AppTranslocation/") {
            return true
        }
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeIsReadOnlyKey])
        if values?.volumeIsReadOnly == true {
            return true
        }
        return path.hasPrefix("/Volumes/")
    }

    /// Offers to copy the app into Applications and relaunch from there. Returns true when the app
    /// is being moved (and the caller should stop launching).
    static func offerMoveIfNeeded() -> Bool {
        guard isTemporary else { return false }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Move Calenbar to Applications?")
        alert.informativeText = String(localized: "install.moveExplanation")
        alert.addButton(withTitle: String(localized: "Move to Applications"))
        alert.addButton(withTitle: String(localized: "Not Now"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        return moveToApplications()
    }

    private static func moveToApplications() -> Bool {
        let source = URL(fileURLWithPath: Bundle.main.bundlePath)
        // The user's own Applications folder needs no administrator password.
        let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")
        let destination = folder.appending(path: source.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            // Downloaded files carry a quarantine flag; the copy is ours now.
            try? FileManager.default.setAttributes([.extensionHidden: true], ofItemAtPath: destination.path)
        } catch {
            let failure = NSAlert(error: error)
            failure.messageText = String(localized: "Calenbar couldn’t be moved")
            failure.runModal()
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }
}
