import AppKit

MainActor.assumeIsolated {
    if let directory = PreviewRenderer.outputDirectory(from: CommandLine.arguments) {
        _ = NSApplication.shared
        do {
            try PreviewRenderer.renderAll(to: directory)
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("previews: \(error)\n".utf8))
            exit(1)
        }
    }
    // A second copy (e.g. opened from Finder while the login agent runs) just exits.
    guard SingleInstance.claim() else { exit(0) }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Menu bar only: no Dock icon, no app menu.
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
