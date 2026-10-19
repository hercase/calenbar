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
    /// Starting width on a notched screen, before anything is learned. Deliberately modest: once macOS
    /// pushes the item left of the notch it doesn't bring it back on its own.
    private static let notchStartWidth = 160.0
    private static let learnedWidthKey = "notchTitleWidth"
    private static let learnedWideWidthKey = "wideTitleWidth"
    /// AppKit remembers where the user put the item under this name, so hiding and re-showing it
    /// (the notch search does that) and relaunching keep its place instead of sending it to the far left.
    private static let autosaveName = "Calenbar"

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let onClick: (NSStatusBarButton) -> Void
    private let onOpenSettings: () -> Void
    /// Resting the pointer on the item shows the event's card.
    private var hover: HoverPreview?
    private let warningIcon = NSImage(
        systemSymbolName: "exclamationmark.triangle", accessibilityDescription: String(localized: "Warning"))
    private let idleIcon = NSImage(systemSymbolName: "calendar", accessibilityDescription: String(localized: "Calendar"))

    /// The app's icon in every state: a calendar showing today's date (with or without a title next to it).
    private var todayIcon: NSImage? {
        let day = Calendar.current.component(.day, from: model.now)
        return DateIcon.image(day: day, showsBadge: model.updater.pending != nil)
    }

    /// Extra shrinking applied only if macOS still hides the item despite the computed budget.
    private var occlusionPenalty = 0.0
    /// On a notched MacBook: the widest title known to keep the item right of the notch. It only ever
    /// shrinks (and is remembered across launches), so the item never jumps over the notch again.
    /// nil when even the narrowest title doesn't fit there.
    private var notchBudget: Double? = {
        let saved = UserDefaults.standard.double(forKey: learnedWidthKey)
        return saved > 0 ? saved : notchStartWidth
    }()
    /// Displays without a notch, "Automatic" width: the widest title known not to collide with the
    /// menus of the apps in use (macOS hides the item when it would). Shrinks only, remembered.
    private var wideBudget: Double = {
        let saved = UserDefaults.standard.double(forKey: learnedWideWidthKey)
        return saved > 0 ? saved : widestTitle
    }()
    private var placementCheckPending = false
    private var renderedEventKey: String?
    private var lastTitle: String?
    private var attentionTimer: Timer?

    init(
        model: AppModel,
        isPanelOpen: @escaping () -> Bool,
        onOpenSettings: @escaping () -> Void,
        onClick: @escaping (NSStatusBarButton) -> Void
    ) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.onClick = onClick
        // macOS decides where third-party items go (new ones land at the far left); the user can
        // Command-drag it next to the clock and, thanks to the autosave name, it stays there.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = Self.autosaveName

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.wantsLayer = true
            button.layer?.cornerRadius = 4
            hover = HoverPreview(model: model, button: button, isPanelOpen: isPanelOpen)
        }
        observeSpaceChanges()
        observeContinuously { [weak self] in self?.render() }
        watchTitleWidthSetting()
    }

    @objc private func clicked() {
        hover?.close()
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
            return
        }
        if model.calendar.access == .denied {
            CalendarService.openPrivacySettings()
            return
        }
        onClick(button)
    }

    /// Right click: the same actions as the panel's "•••" menu, without opening the panel.
    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if let update = model.updater.pending {
            let title =
                update.isReadyToInstall
                ? String(localized: "Restart to Update") : String(localized: "Update to \(update.version)…")
            menu.addItem(withTitle: title, action: #selector(installUpdate), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        let shortcut = model.settings.joinShortcut
        let join = menu.addItem(
            withTitle: String(localized: "Join Next Meeting"), action: #selector(joinNext),
            keyEquivalent: shortcut?.menuKeyEquivalent ?? "")
        join.keyEquivalentModifierMask = shortcut?.flags ?? []
        join.target = self
        join.isEnabled = model.nextMeeting != nil
        menu.addItem(.separator())
        let hide = menu.addItem(
            withTitle: String(localized: "Hide Event Titles"), action: #selector(toggleHideTitles), keyEquivalent: "")
        hide.target = self
        hide.state = model.settings.hideTitlesInMenuBar ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Open Calendar"), action: #selector(openCalendar), keyEquivalent: "").target =
            self
        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit Calenbar"), action: #selector(quit), keyEquivalent: "q").target = self
        // Attaching a menu makes the button pop it up on click; detach right after so left clicks keep opening the panel.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func joinNext() { model.joinNextMeeting() }
    @objc private func installUpdate() { model.updater.checkForUpdates() }
    @objc private func toggleHideTitles() { model.settings.hideTitlesInMenuBar.toggle() }
    @objc private func openCalendar() { model.calendar.openCalendarApp() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    func render() {
        guard let button = statusItem.button else { return }

        switch model.calendar.access {
        case .denied:
            set(button, image: warningIcon, title: String(localized: "Calendar access"))
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
            renderedEventKey = event?.key
            occlusionPenalty = 0
        }
        updateAttention(for: event)

        guard let event else {
            set(button, image: todayIcon, title: "")
            button.toolTip =
                model.settings.titleHorizon == .today
                ? String(localized: "No more events today") : String(localized: "Nothing coming up")
            return
        }

        let icon = todayIcon
        let font = NSFont.menuBarFont(ofSize: 0)
        let shownTitle = model.menuBarTitle(for: event)
        let title = TitleWidthFitter.fit(
            title: shownTitle,
            suffix: TitleFormatter.suffix(for: event, now: model.now),
            maxWidth: titleBudget
        ) { text in
            Double((text as NSString).size(withAttributes: [.font: font]).width)
        }
        set(button, image: icon, title: title)
        button.toolTip = model.settings.hideTitlesInMenuBar ? shownTitle : "\(shownTitle) — \(event.calendarTitle)"
        schedulePlacementCheck()
    }

    private func set(_ button: NSStatusBarButton, image: NSImage?, title: String) {
        // Most minute ticks change nothing; re-setting the same values would still re-lay out the item.
        guard button.image !== image || lastTitle != title else { return }
        lastTitle = title
        image?.isTemplate = true
        button.image = image
        button.title = title.isEmpty ? "" : (image == nil ? title : " " + title)
        let spoken = title.isEmpty ? image?.accessibilityDescription ?? "" : title
        button.setAccessibilityLabel("Calenbar, \(spoken)")
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
    ///   Wider and macOS moves it left of the notch among the app menus, or hides it. A fixed width
    ///   from Settings is the starting point of that search, so a wider choice is tried again.
    /// - Other displays (or no room at all right of the notch): the width chosen in Settings, or with
    ///   "Automatic" the learned width that macOS hasn't hidden for colliding with app menus.
    private var titleBudget: Double {
        let fixed = model.settings.titleWidth.points
        if notchEdge != nil, let notchBudget {
            return min(notchBudget, fixed ?? .infinity)
        }
        if let fixed {
            return clamp(fixed)
        }
        return clamp(wideBudget)
    }

    /// A new choice in Settings restarts the fit from that width; the learned budgets only ever
    /// shrink, so without this a wider choice would never be tried.
    private func watchTitleWidthSetting() {
        var last = model.settings.titleWidth
        observeContinuously { [weak self] in
            guard let self else { return }
            let current = model.settings.titleWidth
            guard current != last else { return }
            last = current
            occlusionPenalty = 0
            if notchEdge != nil {
                setNotchBudget(current.points ?? Self.notchStartWidth)
            } else {
                setWideBudget(current.points ?? Self.widestTitle)
            }
            render()
        }
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
                    // Only a display change invalidates what was learned; an app switch or a wake just
                    // needs a look at whether the item still fits (it shrinks if not).
                    if note.name == NSApplication.didChangeScreenParametersNotification {
                        self?.refit()
                    } else {
                        self?.schedulePlacementCheck()
                    }
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

    /// Displays changed: start again from the default widths; what fits may have changed either way.
    private func refit() {
        occlusionPenalty = 0
        if notchEdge != nil {
            setNotchBudget(Self.notchStartWidth)
        } else {
            setWideBudget(Self.widestTitle)
        }
        render()
    }

    private static var isScreenLocked: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    private func setNotchBudget(_ width: Double?) {
        notchBudget = width
        UserDefaults.standard.set(width ?? 0, forKey: Self.learnedWidthKey)
    }

    private func setWideBudget(_ width: Double) {
        wideBudget = width
        UserDefaults.standard.set(width, forKey: Self.learnedWideWidthKey)
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
        // A hidden menu bar (full-screen app) or a locked screen says nothing about space.
        guard NSMenu.menuBarVisible(), !Self.isScreenLocked, let window = statusItem.button?.window else { return }
        let isVisible = window.occlusionState.contains(.visible)

        if let edge = notchEdge, let current = notchBudget {
            let placed = isVisible && window.frame.minX >= edge - 1
            searchNotchBudget(current: current, placed: placed)
        } else if !isVisible, titleBudget > Self.narrowestTitle {
            // Hidden by macOS: the title collided with the app menus (or the bar is just full).
            // Automatic remembers the narrower width; a fixed width shrinks only for now.
            if model.settings.titleWidth == .automatic {
                setWideBudget(max(Self.narrowestTitle, wideBudget - Self.shrinkStep))
            } else {
                occlusionPenalty += Self.shrinkStep
            }
            render()
        }
    }

    /// The item landed left of the notch (or hidden): narrow the title and make macOS lay the item out
    /// again, since it won't move an item back over the notch by itself.
    private func searchNotchBudget(current: Double, placed: Bool) {
        guard !placed else { return }
        let narrower = current - Self.shrinkStep
        setNotchBudget(narrower >= Self.narrowestTitle ? narrower : nil)
        statusItem.isVisible = false
        render()
        statusItem.isVisible = true
    }

}

// MARK: - Flashing as an event approaches

extension StatusBarController {

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
        timer.tolerance = 0.1
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
