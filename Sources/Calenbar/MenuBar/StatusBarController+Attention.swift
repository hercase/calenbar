import AppKit
import CalenbarCore

// MARK: - Flashing as an event approaches

extension StatusBarController {

    /// What the per-second timer is watching: the shown event about to start (red, and the pings), or
    /// the meeting right behind the ongoing one (one yellow burst).
    private enum Attention {
        case start(CalendarEvent)
        case followUp(CalendarEvent)
    }

    func updateAttention(for event: CalendarEvent?) {
        guard let event, attention(for: event) != nil else {
            attentionTimer?.invalidate()
            attentionTimer = nil
            if !isPreviewingFlash { setFlash(nil) }
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

    /// The next meeting, while the bar should name it instead of the ongoing `event`.
    func followUpToName(for event: CalendarEvent) -> CalendarEvent? {
        guard model.settings.flashEnabled, model.settings.flashFollowUp, !isPreviewingFlash,
            let next = model.titleFollowUp(to: event),
            AttentionPolicy.showsFollowUpTitle(start: next.start, now: Date())
        else { return nil }
        return next
    }

    private func attention(for event: CalendarEvent) -> Attention? {
        let settings = model.settings
        let now = Date()
        if settings.flashEnabled || settings.attentionSound, AttentionPolicy.needsSecondTicks(start: event.start, now: now) {
            return .start(event)
        }
        guard settings.flashEnabled, settings.flashFollowUp, let next = model.titleFollowUp(to: event) else { return nil }
        return AttentionPolicy.needsFollowUpTicks(start: next.start, now: now) ? .followUp(next) : nil
    }

    private func attentionTick() {
        guard let event = model.titleEvent, let attention = attention(for: event) else {
            updateAttention(for: nil)
            return
        }
        if isPreviewingFlash { return }
        let settings = model.settings
        let now = Date()
        switch attention {
        case .start(let event):
            let fromFive = settings.flashFromFiveMinutes
            let isOn =
                settings.flashEnabled && AttentionPolicy.isFlashOn(start: event.start, now: now, fromFiveMinutes: fromFive)
            setFlash(isOn ? FlashPreview.red.nsColor : nil)
            if settings.attentionSound, AttentionPolicy.shouldPing(start: event.start, now: now, fromFiveMinutes: fromFive) {
                NSSound(named: "Ping")?.play()
            }
        case .followUp(let next):
            // Title first: setting it drops the black-on-yellow styling, which `setFlash` puts back.
            if (followUpToName(for: event) != nil) != showsFollowUpTitle {
                render()
            }
            setFlash(AttentionPolicy.isFollowUpFlashOn(start: next.start, now: now) ? .systemYellow : nil)
        }
    }

    /// Settings' preview: a burst of the chosen color right away (5 flashes, a second on and a second off).
    /// It takes over from a real countdown (which resumes on the next tick). Pressing the other color
    /// switches to it; pressing the running one stops it.
    func previewFlash(_ kind: FlashPreview) {
        let wasRunning = model.flashPreviewing
        stopPreview()
        if wasRunning == kind { return }

        let color = kind.nsColor
        model.flashPreviewing = kind
        previewTask = Task { [weak self] in
            for _ in 0..<5 {
                self?.setFlash(color)
                self?.model.flashPhaseOn = true
                try? await Task.sleep(for: .seconds(1))
                self?.setFlash(nil)
                self?.model.flashPhaseOn = false
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            self?.previewTask = nil
            self?.model.flashPreviewing = nil
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        model.flashPreviewing = nil
        model.flashPhaseOn = false
        setFlash(nil)
    }

    private func setFlash(_ color: NSColor?) {
        guard let button = statusItem.button else { return }
        button.layer?.backgroundColor = color?.cgColor
        // White on yellow is unreadable: put the title and icon in black while it's yellow.
        let onYellow = color == .systemYellow
        button.contentTintColor = onYellow ? .black : nil
        if onYellow {
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [.foregroundColor: NSColor.black, .font: NSFont.menuBarFont(ofSize: 0)])
        } else if button.attributedTitle.length > 0 {
            button.title = button.title
        }
    }
}
