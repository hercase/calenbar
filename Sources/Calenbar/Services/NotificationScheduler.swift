import CalenbarCore
import Foundation
import UserNotifications

/// Schedules a system notification shortly before each event, with a Join action for meetings.
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private enum Identifier {
        static let meetingCategory = "MEETING"
        static let eventCategory = "EVENT"
        static let joinAction = "JOIN"
        static let linkKey = "link"
    }

    private let model: AppModel
    /// UserNotifications crashes outside an app bundle (e.g. `swift run`), so it is only touched when bundled.
    private let center: UNUserNotificationCenter? =
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    private var zoneObserver: NSObjectProtocol?

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
        zoneObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reschedule() }
        }
        // Ask for permission as soon as calendar access exists, whether it was granted at launch or
        // later from the panel's "Allow Access" button. The system only ever prompts once.
        observeContinuously { [weak self] in
            guard let self, model.calendar.access == .granted else { return }
            Task { await self.requestAuthorization() }
        }
    }

    func requestAuthorization() async {
        _ = try? await center?.requestAuthorization(options: [.alert, .sound])
    }

    private func reschedule() {
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
                content.userInfo = [Identifier.linkKey: link.webURL.absoluteString]
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
        guard isJoin,
            let string = response.notification.request.content.userInfo[Identifier.linkKey] as? String,
            let link = MeetingLinkDetector.detect(url: URL(string: string), location: nil, notes: nil)
        else { return }
        await MainActor.run { MeetingOpener.open(link) }
    }
}
