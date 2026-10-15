import Foundation

/// A calendar event, decoupled from EventKit so the core logic can be tested with plain values.
public struct CalendarEvent: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    /// Identifier shared by every occurrence of a recurring event (EventKit's `calendarItemExternalIdentifier`).
    public let externalID: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarID: String
    public let calendarTitle: String
    public let calendarColorHex: String
    public let isDeclined: Bool
    public let hasOtherAttendees: Bool
    public let url: URL?
    public let location: String?
    public let notes: String?
    public let attendees: [Attendee]
    /// Your own answer to the invitation.
    public let myStatus: ParticipationStatus
    public let isRecurring: Bool

    public init(
        id: String,
        externalID: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarID: String,
        calendarTitle: String,
        calendarColorHex: String,
        isDeclined: Bool,
        hasOtherAttendees: Bool,
        url: URL?,
        location: String?,
        notes: String?,
        attendees: [Attendee] = [],
        myStatus: ParticipationStatus = .unknown,
        isRecurring: Bool = false
    ) {
        self.id = id
        self.externalID = externalID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
        self.isDeclined = isDeclined
        self.hasOtherAttendees = hasOtherAttendees
        self.url = url
        self.location = location
        self.notes = notes
        self.attendees = attendees
        self.myStatus = myStatus
        self.isRecurring = isRecurring
    }

    /// Stable key for a single occurrence, used to persist Hide/Mute.
    /// Includes the start so hiding one occurrence of a recurring event leaves the others visible.
    public var key: String {
        "\(externalID)|\(Int(start.timeIntervalSince1970))"
    }

    public var meetingLink: MeetingLink? {
        MeetingLinkDetector.detect(url: url, location: location, notes: notes)
    }

    public func isOngoing(at now: Date) -> Bool {
        start <= now && now < end
    }

    /// The same meeting often appears in several calendars (own, shared, team). Keeps one copy per
    /// title + time, preferring the one with a meeting link, then the one with attendees.
    /// Order of first appearance is preserved.
    public static func deduplicated(_ events: [Self]) -> [Self] {
        var order: [String] = []
        var best: [String: Self] = [:]
        for event in events {
            let identity = event.duplicateIdentity
            guard let current = best[identity] else {
                order.append(identity)
                best[identity] = event
                continue
            }
            if event.duplicatePreference > current.duplicatePreference {
                best[identity] = event
            }
        }
        return order.compactMap { best[$0] }
    }

    private var duplicateIdentity: String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedTitle)|\(start.timeIntervalSince1970)|\(end.timeIntervalSince1970)"
    }

    private var duplicatePreference: Int {
        (meetingLink == nil ? 0 : 2) + (hasOtherAttendees ? 1 : 0)
    }
}
