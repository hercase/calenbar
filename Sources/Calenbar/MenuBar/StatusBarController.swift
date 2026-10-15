import AppKit
import CalenbarCore

/// Owns the menu bar item: renders the next event, flashes when it's close, and toggles the panel on click.
@MainActor
final class StatusBarController {
    /// The title uses as much room as the menu bar has, up to this cap.
    private static let widestTitle = 400.0
    /// Below this only the countdown is left; no point shrinking further.
    private static let narrowestTitle = 60.0
    private static let shrinkStep = 40.0
    /// Room taken by the video icon and the button's own padding.
    private static let chromeWidth = 32.0
    /// Breathing room between the active app's last menu and the title.
    private static let gapAfterAppMenus = 24.0
    /// Used when the app menus can't be measured (no Accessibility permission).
    private static let fallbackTitle = 200.0
    /// The notch-side search stops once the remaining range is this narrow.
    private static let searchPrecision = 16.0

    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onClick: (NSStatusBarButton) -> Void
    private let videoIcon = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Video meeting")
    private let warningIcon = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Warning")
    private let idleIcon = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")

    /// Calendar with a checkmark: you're done for today.
    private let doneIcon = NSImage(systemSymbolName: "calendar.badge.checkmark", accessibilityDescription: "No more events today")

    /// Extra shrinking applied only if macOS still hides the item despite the computed budget.
    private var occlusionPenalty = 0.0
    /// On a notched MacBook: the widest title that keeps the item right of the notch, learned by
    /// trying widths (macOS doesn't report free menu bar space). nil when even the narrowest doesn't fit.
    private var notchBudget: Double? = widestTitle
    /// Bounds of an in-progress search for `notchBudget`.
    private var notchSearch: ClosedRange<Double>?
    private var placementCheckPending = false
    private var renderedEventKey: String?
    private var attentionTimer: Timer?

    init(model: AppModel, onClick: @escaping (NSStatusBarButton) -> Void) {
        self.model = model
        self.onClick = onClick

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.imagePosition = .imageLeading
            button.wantsLayer = true
            button.layer?.cornerRadius = 4
        }
        observeSpaceChanges()
        watchAccessibility()
        observeContinuously { [weak self] in self?.render() }
    }

    @objc private func clicked() {
        guard let button = statusItem.button else { return }
        if model.calendar.access == .denied {
            CalendarService.openPrivacySettings()
            return
        }
        onClick(button)
    }

    func render() {
        guard let button = statusItem.button else { return }

        switch model.calendar.access {
        case .denied:
            set(button, image: warningIcon, title: "Calendar access")
            updateAttention(for: nil)
            return
        case .notDetermined:
            set(button, image: idleIcon, title: "")
            updateAttention(for: nil)
            return
        case .granted:
            break
        }

        let event = model.titleEvent
        if event?.key != renderedEventKey {
            // A different title may fit differently; try the full budget again.
            renderedEventKey = event?.key
            occlusionPenalty = 0
            notchBudget = Self.widestTitle
            notchSearch = nil
        }
        updateAttention(for: event)

        guard let event else {
            set(button, image: doneIcon ?? idleIcon, title: "")
            button.toolTip = "No more events today"
            return
        }

        let icon = event.meetingLink == nil ? nil : videoIcon
        let font = NSFont.menuBarFont(ofSize: 0)
        let title = TitleWidthFitter.fit(
            title: TitleFormatter.displayTitle(event),
            suffix: TitleFormatter.suffix(for: event, now: model.now),
            maxWidth: titleBudget
        ) { text in
            Double((text as NSString).size(withAttributes: [.font: font]).width)
        }
        set(button, image: icon, title: title)
        button.toolTip = "\(TitleFormatter.displayTitle(event)) — \(event.calendarTitle)"
        schedulePlacementCheck()
    }

    private func set(_ button: NSStatusBarButton, image: NSImage?, title: String) {
        image?.isTemplate = true
        button.image = image
        button.title = title.isEmpty ? "" : (image == nil ? title : " " + title)
    }

    // MARK: - Automatic width

    private var screen: NSScreen? { statusItem.button?.window?.screen ?? NSScreen.main }

    /// x where the free area right of the notch begins, or nil on displays without a notch.
    private var notchEdge: CGFloat? {
        guard let screen, let rightOfNotch = screen.auxiliaryTopRightArea else { return nil }
        return screen.frame.minX + rightOfNotch.minX
    }

    /// How wide the title may get.
    /// - Notched MacBook: the learned width that keeps the item right of the notch, next to the other icons.
    ///   Wider and macOS moves it left of the notch among the app menus, or hides it.
    /// - Other displays (or no room at all right of the notch): the space after the active app's menus,
    ///   measured via Accessibility, or a fixed fallback without that permission.
    private var titleBudget: Double {
        if notchEdge != nil, let notchBudget {
            return notchBudget
        }
        let window = statusItem.button?.window
        let menusEnd = MenuBarSpace.appMenusMaxX()
        if let window, let screen, let menusEnd, screen.frame.minX...screen.frame.maxX ~= menusEnd {
            return clamp(Double(window.frame.maxX - menusEnd) - Self.gapAfterAppMenus - Self.chromeWidth)
        }
        return clamp(Self.fallbackTitle)
    }

    private func clamp(_ width: Double) -> Double {
        max(Self.narrowestTitle, min(Self.widestTitle, width) - occlusionPenalty)
    }

    private func observeSpaceChanges() {
        let workspace = NSWorkspace.shared.notificationCenter
        // Displays and wake-ups change the room we have; switching apps changes the app menus' width.
        let triggers: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didActivateApplicationNotification),
            (workspace, NSWorkspace.didWakeNotification),
            (workspace, NSWorkspace.screensDidWakeNotification),
            (.default, NSApplication.didChangeScreenParametersNotification),
        ]
        for (center, name) in triggers {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    // App menus never reach the right of the notch, so app switches don't matter there.
                    let isAppSwitch = note.name == NSWorkspace.didActivateApplicationNotification
                    if isAppSwitch, self?.notchEdge != nil, self?.notchBudget != nil {
                        return
                    }
                    self?.refit()
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let window = note.object as? NSWindow, window === self.statusItem.button?.window else { return }
                self.schedulePlacementCheck()
            }
        }
    }

    /// Re-measures as soon as Accessibility is granted or revoked. Tracks only that flag: observing
    /// `refit()` itself would also track the clock and re-fit every minute.
    private func watchAccessibility() {
        withObservationTracking {
            _ = AccessibilityTrust.shared.isTrusted
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refit()
                self?.watchAccessibility()
            }
        }
    }

    /// Forget what we learned and fit again from the widest title.
    private func refit() {
        occlusionPenalty = 0
        notchBudget = Self.widestTitle
        notchSearch = nil
        render()
    }

    /// macOS lays the item out asynchronously; look at where it landed shortly after a change.
    private func schedulePlacementCheck() {
        guard !placementCheckPending else { return }
        placementCheckPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.placementCheckPending = false
            self?.checkPlacement()
        }
    }

    private func checkPlacement() {
        // A hidden menu bar (full-screen app, locked screen) says nothing about space.
        guard NSMenu.menuBarVisible(), let window = statusItem.button?.window else { return }
        let isVisible = window.occlusionState.contains(.visible)

        if let edge = notchEdge, let current = notchBudget {
            let placed = isVisible && window.frame.minX >= edge - 1
            searchNotchBudget(current: current, placed: placed)
        } else if !isVisible, titleBudget > Self.narrowestTitle {
            // Safety net for crowded menu bars without a notch: shrink until the item shows up.
            occlusionPenalty += Self.shrinkStep
            render()
        }
    }

    /// Binary search for the widest title that still sits right of the notch.
    private func searchNotchBudget(current: Double, placed: Bool) {
        if notchSearch == nil {
            guard !placed else { return }  // Fits as is; nothing to do.
            notchSearch = Self.narrowestTitle...current
        }
        guard var range = notchSearch else { return }

        if placed {
            range = current...range.upperBound
        } else {
            range = range.lowerBound...current
        }

        if range.upperBound - range.lowerBound <= Self.searchPrecision {
            notchSearch = nil
            let fitsAtNarrowest = placed || range.lowerBound > Self.narrowestTitle
            // Even the narrowest title doesn't fit right of the notch: fall back to the app-menus budget.
            notchBudget = fitsAtNarrowest ? range.lowerBound : nil
        } else {
            notchSearch = range
            notchBudget = (range.lowerBound + range.upperBound) / 2
        }
        render()
    }

    // MARK: - Flashing as an event approaches

    private func updateAttention(for event: CalendarEvent?) {
        let settings = model.settings
        let wanted = settings.flashEnabled || settings.attentionSound
        guard wanted, let event, AttentionPolicy.needsSecondTicks(start: event.start, now: Date()) else {
            attentionTimer?.invalidate()
            attentionTimer = nil
            setFlash(false)
            return
        }
        guard attentionTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.attentionTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        attentionTimer = timer
        attentionTick()
    }

    private func attentionTick() {
        let settings = model.settings
        guard let event = model.titleEvent, AttentionPolicy.needsSecondTicks(start: event.start, now: Date()) else {
            updateAttention(for: nil)
            return
        }
        let now = Date()
        let fromFive = settings.flashFromFiveMinutes
        setFlash(settings.flashEnabled && AttentionPolicy.isFlashOn(start: event.start, now: now, fromFiveMinutes: fromFive))
        if settings.attentionSound, AttentionPolicy.shouldPing(start: event.start, now: now, fromFiveMinutes: fromFive) {
            NSSound(named: "Ping")?.play()
        }
    }

    private func setFlash(_ isOn: Bool) {
        statusItem.button?.layer?.backgroundColor = isOn ? NSColor.systemRed.cgColor : nil
    }
}
