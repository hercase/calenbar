import AppKit
import CalenbarCore
import Foundation
import Observation
import UserNotifications

/// Schedules a system notification shortly before each event, with a Join action for meetings.
@MainActor
@Observable
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    /// macOS's answer to "may Calenbar notify?", refreshed when the app becomes active.
    private(set) var isDeniedBySystem = false

    private enum Identifier {
        static let meetingCategory = "MEETING"
        static let eventCategory = "EVENT"
        static let joinAction = "JOIN"
        static let linkKey = "link"
        static let eventKey = "eventKey"
    }

    @ObservationIgnored private let model: AppModel
    /// UserNotifications crashes outside an app bundle (e.g. `swift run`), so it is only touched when bundled.
    @ObservationIgnored private let center: UNUserNotificationCenter? =
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(model: AppModel) {
        self.model = model
        super.init()
        guard let center else { return }
        center.delegate = self
        let join = UNNotificationAction(
            identifier: Identifier.joinAction, title: String(localized: "Join"), options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Identifier.meetingCategory, actions: [join], intentIdentifiers: []),
            UNNotificationCategory(identifier: Identifier.eventCategory, actions: [], intentIdentifiers: []),
        ])
        // Reschedule only when events or settings change; deliberately not on every clock tick.
        observeContinuously { [weak self] in self?.reschedule() }
        let zoneChanged = Notification.Name.NSSystemTimeZoneDidChange
        observers.append(
            NotificationCenter.default.addObserver(forName: zoneChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reschedule() }
            })
        // The user may flip the permission in System Settings; look again whenever they come back.
        let becameActive = NSApplication.didBecomeActiveNotification
        observers.append(
            NotificationCenter.default.addObserver(forName: becameActive, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshAuthorization() }
            })
        refreshAuthorization()
        // Ask for permission as soon as calendar access exists, whether it was granted at launch or
        // later from the panel's "Allow Access" button. The system only ever prompts once.
        observeContinuously { [weak self] in
            guard let self, model.calendar.access == .granted else { return }
            Task { await self.requestAuthorization() }
        }
    }

    func requestAuthorization() async {
        _ = try? await center?.requestAuthorization(options: [.alert, .sound])
        refreshAuthorization()
    }

    func refreshAuthorization() {
        guard let center else { return }
        Task { [weak self] in
            let status = await center.notificationSettings().authorizationStatus
            self?.isDeniedBySystem = status == .denied
        }
    }

    /// Settings' "Send Test Notification": one banner right now, so people can see what to expect.
    func sendTest() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "This is how a notification looks")
        content.body = String(localized: "Calenbar sends one like this before each meeting, with a Join button.")
        content.sound = .default
        content.categoryIdentifier = Identifier.eventCategory
        center.add(UNNotificationRequest(identifier: "test", content: content, trigger: nil))
    }

    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func reschedule() {
        // Reading `lastReload` re-runs this after each reload, so a meeting two days out gets its
        // request once it enters the 24-hour window even if the event list never changed.
        _ = model.calendar.lastReload
        let settings = model.settings
        let events = model.events(for: .notify)
        let enabled = settings.notificationsEnabled
        let lead = TimeInterval(settings.notifyLeadMinutes * 60)
        guard let center else { return }

        center.removeAllPendingNotificationRequests()
        guard enabled else { return }

        let now = Date()
        let horizon = now.addingTimeInterval(24 * 3_600)
        for event in events where event.start < horizon {
            let fireDate = event.start.addingTimeInterval(-lead)
            let delay = fireDate.timeIntervalSince(now)
            guard delay > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = TitleFormatter.displayTitle(event)
            content.body =
                lead == 0
                ? String(localized: "Starting now · \(EventTimeText.range(event))")
                : String(localized: "In \(TitleFormatter.compactDuration(lead)) · \(EventTimeText.range(event))")
            content.sound = .default
            if let link = event.meetingLink {
                content.categoryIdentifier = Identifier.meetingCategory
                content.userInfo = [Identifier.linkKey: link.webURL.absoluteString, Identifier.eventKey: event.key]
            } else {
                content.categoryIdentifier = Identifier.eventCategory
            }
            // A calendar trigger fires at the wall-clock moment, which survives sleep; an interval drifts.
            // The zone is attached so the instant is unambiguous; a zone change reschedules anyway.
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            components.timeZone = TimeZone.current
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: event.key, content: content, trigger: trigger))
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let isJoin =
            response.actionIdentifier == Identifier.joinAction
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier
        let userInfo = response.notification.request.content.userInfo
        guard isJoin,
            let string = userInfo[Identifier.linkKey] as? String,
            let link = MeetingLinkDetector.detect(url: URL(string: string), location: nil, notes: nil)
        else { return }
        let eventKey = userInfo[Identifier.eventKey] as? String
        await MainActor.run { MeetingOpener.open(link, eventKey: eventKey) }
    }
}
