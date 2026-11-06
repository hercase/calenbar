import Foundation

// MARK: - Position

extension StatusBarController {
    /// AppKit remembers where the user put the item under this name, so relaunching keeps its place
    /// instead of sending it to the far left.
    static let autosaveName = "Calenbar"
    /// Where AppKit stores that place. Hiding the item deletes it, so it's put back before re-showing.
    static let positionKey = "NSStatusItem Preferred Position \(autosaveName)"
    /// Our own copy, to restore a place AppKit already lost.
    static let savedPositionKey = "menuBarPosition"

    /// Keeps a copy of the place the user gave the item (it changes whenever they Command-drag it).
    static func rememberPosition() {
        let defaults = UserDefaults.standard
        guard let position = defaults.object(forKey: positionKey) else { return }
        defaults.set(position, forKey: savedPositionKey)
    }

    /// Puts the remembered place back if AppKit dropped it, so the item doesn't land at the far left.
    static func restorePosition() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: positionKey) == nil, let saved = defaults.object(forKey: savedPositionKey) else { return }
        defaults.set(saved, forKey: positionKey)
    }
}
