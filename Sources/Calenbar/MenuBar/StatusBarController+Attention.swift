import AppKit
import CalenbarCore

// MARK: - Flashing as an event approaches

extension StatusBarController {

    func updateAttention(for event: CalendarEvent?) {
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
