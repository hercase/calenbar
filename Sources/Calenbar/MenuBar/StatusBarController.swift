import AppKit
import CalenbarCore

/// Owns the menu bar item: renders the next event, flashes when it's close, and toggles the panel on click.
@MainActor
final class StatusBarController {
    /// No title width, fixed or learned, goes past this.
    private static let widestTitle = 400.0
    /// "Automatic" uses as much room as the menu bar has, up to this. Even on a wide display a longer
    /// title crowds the bar more than it informs; the full one is a hover away.
    private static let automaticTitle = 240.0
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

    let model: AppModel
    let statusItem: NSStatusItem
    private let onClick: (NSStatusBarButton) -> Void
    let onOpenSettings: () -> Void
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
    /// On a notched MacBook: the widest title known to keep the item right of the notch, remembered
    /// across launches. It shrinks when the item lands left of the notch and steps back up through
    /// `widthProbe`. nil when even the narrowest title doesn't fit there.
    private var notchBudget: Double? = {
        let saved = UserDefaults.standard.double(forKey: learnedWidthKey)
        return saved > 0 ? saved : notchStartWidth
    }()
    /// Displays without a notch, "Automatic" width: the widest title known not to collide with the
    /// menus of the apps in use (macOS hides the item when it would). Remembered; grows back like `notchBudget`.
    private var wideBudget: Double = {
        let saved = UserDefaults.standard.double(forKey: learnedWideWidthKey)
        return saved > 0 ? min(saved, automaticTitle) : automaticTitle
    }()
    private var placementCheckPending = false
    /// When a cut title next tries one step wider, so the item gets its room back once the bar has some.
    private var widthProbe = WidthProbe()
    /// A wider title is on screen and the next placement check decides whether it stays.
    private var isProbing = false
    /// The last placement check found the item hidden and asked for a second look.
    private var wasHiddenOnce = false
    private var renderedEventKey: String?
    private var lastTitle: String?
    var attentionTimer: Timer?
    /// Settings' flash preview in progress; while it runs, re-renders and the countdown leave the bar alone.
    var previewTask: Task<Void, Never>?
    var isPreviewingFlash: Bool { previewTask != nil }

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
        Self.restorePosition()
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
        let suffix = TitleFormatter.suffix(for: event, now: model.now)
        let title = TitleWidthFitter.fit(title: shownTitle, suffix: suffix, maxWidth: titleBudget) { text in
            Double((text as NSString).size(withAttributes: [.font: font]).width)
        }
        set(button, image: icon, title: title)
        button.toolTip = model.settings.hideTitlesInMenuBar ? shownTitle : "\(shownTitle) — \(event.calendarTitle)"
        schedulePlacementCheck()
        if title != shownTitle + TitleFormatter.separator + suffix {
            probeWiderIfDue()
        }
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

    /// A new choice in Settings restarts the fit from that width at once, instead of probing up to it.
    private func watchTitleWidthSetting() {
        var last = model.settings.titleWidth
        observeContinuously { [weak self] in
            guard let self else { return }
            let current = model.settings.titleWidth
            guard current != last else { return }
            last = current
            occlusionPenalty = 0
            widthProbe = WidthProbe()
            if notchEdge != nil {
                setNotchBudget(current.points ?? Self.notchStartWidth)
            } else {
                setWideBudget(current.points ?? Self.automaticTitle)
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
        widthProbe = WidthProbe()
        if notchEdge != nil {
            setNotchBudget(Self.notchStartWidth)
        } else {
            setWideBudget(Self.automaticTitle)
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
        Self.rememberPosition()
        let wasProbing = isProbing
        isProbing = false
        // A hidden menu bar (full-screen app) or a locked screen says nothing about space. A probe left
        // undecided stays; the next check shrinks it if it doesn't fit.
        guard NSMenu.menuBarVisible(), !Self.isScreenLocked, let window = statusItem.button?.window else { return }
        let isVisible = window.occlusionState.contains(.visible)
        // macOS hides the item for a moment while it lays the bar out again (after our own re-show, or
        // another app's item appearing). Only a second look that still finds it hidden counts.
        if !isVisible, !wasHiddenOnce {
            wasHiddenOnce = true
            isProbing = wasProbing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.checkPlacement() }
            return
        }
        wasHiddenOnce = false

        let fits: Bool
        if let edge = notchEdge, notchBudget != nil {
            fits = isVisible && window.frame.minX >= edge - 1
        } else {
            fits = isVisible || titleBudget <= Self.narrowestTitle
        }
        guard !fits else {
            if wasProbing {
                widthProbe.fit()
                render()
            }
            return
        }

        if wasProbing {
            widthProbe.didNotFit(now: Date())
        } else {
            widthProbe.shrank(now: Date())
        }
        if notchEdge != nil, let current = notchBudget {
            shrinkNotchBudget(from: current)
        } else {
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
    private func shrinkNotchBudget(from current: Double) {
        let narrower = current - Self.shrinkStep
        setNotchBudget(narrower >= Self.narrowestTitle ? narrower : nil)
        Self.rememberPosition()
        statusItem.isVisible = false
        render()
        Self.restorePosition()
        statusItem.isVisible = true
    }
}

// MARK: - Growing back

extension StatusBarController {
    /// Tries the title one step wider when it's cut and the last try is long enough ago. Not while the
    /// item flashes for a meeting about to start: a probe that doesn't fit makes it jump for a moment.
    private func probeWiderIfDue() {
        guard !isProbing, attentionTimer == nil, widthProbe.isDue(now: Date()),
            NSMenu.menuBarVisible(), !Self.isScreenLocked, widen()
        else { return }
        isProbing = true
        render()
    }

    /// Sets the width learned for this display one step wider; false when it's already as wide as the
    /// settings allow.
    private func widen() -> Bool {
        let fixed = model.settings.titleWidth.points
        if notchEdge != nil {
            let ceiling = fixed ?? Self.notchStartWidth
            guard
                let next = WidthProbe.wider(
                    than: notchBudget, step: Self.shrinkStep, narrowest: Self.narrowestTitle, ceiling: ceiling)
            else { return false }
            setNotchBudget(next)
            return true
        }
        if fixed != nil {
            guard occlusionPenalty > 0 else { return false }
            occlusionPenalty = max(0, occlusionPenalty - Self.shrinkStep)
            return true
        }
        guard
            let next = WidthProbe.wider(
                than: wideBudget, step: Self.shrinkStep, narrowest: Self.narrowestTitle, ceiling: Self.automaticTitle)
        else { return false }
        setWideBudget(next)
        return true
    }
}
