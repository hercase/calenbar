import AppKit
import CalenbarCore
import Foundation
import Observation

/// Wires the services together and derives what every surface (menu bar, panel, alerts) shows.
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let calendar: CalendarService
    let clock: MinuteClock
    let updater = Updater()
    /// Set by the app delegate once the scheduler exists; Settings reads the permission state from it.
    var notifications: NotificationScheduler?

    init(settings: AppSettings, calendar: CalendarService, clock: MinuteClock) {
        self.settings = settings
        self.calendar = calendar
        self.clock = clock
    }

    var now: Date { clock.now }

    /// The event shown in the menu bar, or nil when nothing qualifies.
    var titleEvent: CalendarEvent? {
        let candidates = settings.eventFilter.apply(calendar.upcoming, for: .title)
        return TitleSelector(rule: settings.titleRule, horizon: settings.titleHorizon).select(from: candidates, now: now)
    }

    /// The meeting the global shortcut and "Join Next Meeting" open.
    var nextMeeting: CalendarEvent? {
        MeetingPicker.next(titleEvent: titleEvent, candidates: events(for: .title), now: now)
    }

    /// Joins it, or beeps when there's nothing to join.
    func joinNextMeeting() {
        guard let event = nextMeeting, let link = event.meetingLink else {
            NSSound.beep()
            return
        }
        MeetingOpener.open(link, eventKey: event.key)
    }

    /// Opens the service's instant-meeting page in the user's meeting browser.
    func startNewMeeting(_ provider: MeetingProvider) {
        if let url = provider.newMeetingURL {
            MeetingOpener.openInBrowser(url)
        }
    }

    /// What the menu bar prints for an event: its title, or a stand-in while the screen is shared.
    func menuBarTitle(for event: CalendarEvent) -> String {
        settings.hideTitlesInMenuBar ? TitleFormatter.privateTitle(event) : TitleFormatter.displayTitle(event)
    }

    func events(for purpose: CalendarPurpose) -> [CalendarEvent] {
        settings.eventFilter.apply(calendar.upcoming, for: purpose)
    }

    func listEvents(on day: Date) -> [CalendarEvent] {
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        let source =
            calendar.upcoming.contains { $0.start >= start && $0.start < end }
            ? calendar.upcoming
            : calendar.events(from: start, to: end)
        return settings.eventFilter
            .apply(source, for: .list)
            .filter { $0.start < end && $0.end > start }
    }

    /// Opens the event where the user answers invitations: Google Calendar on the web for Google
    /// events (by default), Calendar.app otherwise.
    func openEvent(_ event: CalendarEvent) {
        let googleURL = GoogleCalendarLink.url(
            externalID: event.externalID,
            calendarTitle: event.calendarTitle,
            start: event.start,
            isRecurring: event.isRecurring
        )
        switch (settings.openEventsIn, googleURL) {
        case (.automatic, let url?), (.googleWeb, let url?):
            MeetingOpener.openInBrowser(url)
        default:
            calendar.openInCalendar(event)
        }
    }

    /// Where `openEvent` takes this event, for button labels ("Answer in Google Calendar").
    func eventDestinationName(_ event: CalendarEvent) -> String {
        let isGoogle = GoogleCalendarLink.isGoogleEvent(externalID: event.externalID)
        switch settings.openEventsIn {
        case .calendarApp: return String(localized: "Calendar")
        case .automatic, .googleWeb: return isGoogle ? "Google Calendar" : String(localized: "Calendar")
        }
    }

    func isSkipped(_ event: CalendarEvent) -> Bool {
        settings.mutedKeys.contains(event.key)
    }
}

/// Re-runs `apply` whenever any observable value it read changes.
@MainActor
func observeContinuously(_ apply: @escaping @MainActor () -> Void) {
    withObservationTracking {
        apply()
    } onChange: {
        Task { @MainActor in observeContinuously(apply) }
    }
}
