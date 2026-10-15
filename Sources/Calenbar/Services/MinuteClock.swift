import AppKit
import Observation

/// Publishes the current time at every minute boundary, and again after the Mac wakes up
/// or the clock/time zone changes, so countdowns never drift.
@MainActor
@Observable
final class MinuteClock {
    private(set) var now = Date()

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            })
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            observers.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.tick() }
                })
        }
        scheduleNextTick()
    }

    func tick() {
        now = Date()
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        timer?.invalidate()
        let seconds = Calendar.current.component(.second, from: Date())
        // Small offset so the tick lands just after the boundary, not just before it.
        let delay = TimeInterval(60 - seconds) + 0.05
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
