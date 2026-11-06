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
            setFlash(nil)
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
        let settings = model.settings
        let now = Date()
        switch attention {
        case .start(let event):
            let fromFive = settings.flashFromFiveMinutes
            let isOn =
                settings.flashEnabled && AttentionPolicy.isFlashOn(start: event.start, now: now, fromFiveMinutes: fromFive)
            setFlash(isOn ? .systemRed : nil)
            if settings.attentionSound, AttentionPolicy.shouldPing(start: event.start, now: now, fromFiveMinutes: fromFive) {
                NSSound(named: "Ping")?.play()
            }
        case .followUp(let next):
            setFlash(AttentionPolicy.isFollowUpFlashOn(start: next.start, now: now) ? .systemYellow : nil)
        }
    }

    /// Settings' preview: the yellow burst right away (5 flashes, a second on and a second off).
    /// Skipped while a real countdown is flashing.
    func previewFollowUpFlash() {
        guard attentionTimer == nil else { return }
        for flash in 0..<5 {
            let start = Double(flash) * 2
            DispatchQueue.main.asyncAfter(deadline: .now() + start) { [weak self] in self?.setFlash(.systemYellow) }
            DispatchQueue.main.asyncAfter(deadline: .now() + start + 1) { [weak self] in self?.setFlash(nil) }
        }
    }

    private func setFlash(_ color: NSColor?) {
        statusItem.button?.layer?.backgroundColor = color?.cgColor
    }
}
