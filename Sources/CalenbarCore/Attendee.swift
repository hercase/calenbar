import Foundation

/// The current user's (or an attendee's) answer to an invitation.
public enum ParticipationStatus: String, Sendable, Hashable {
    /// No invitation involved (e.g. an event you created for yourself) or the status is unavailable.
    case unknown
    case pending
    case accepted
    case tentative
    case declined
}

public struct Attendee: Hashable, Sendable {
    public enum Kind: String, Sendable, Hashable {
        case person
        case room
        case resource
        case group
    }

    public let name: String?
    public let email: String?
    public let status: ParticipationStatus
    public let kind: Kind
    public let isCurrentUser: Bool
    public let isOrganizer: Bool

    public init(
        name: String?,
        email: String?,
        status: ParticipationStatus,
        kind: Kind,
        isCurrentUser: Bool,
        isOrganizer: Bool
    ) {
        self.name = name
        self.email = email
        self.status = status
        self.kind = kind
        self.isCurrentUser = isCurrentUser
        self.isOrganizer = isOrganizer
    }

    public var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return email ?? "Unknown"
    }
}

extension CalendarEvent {
    /// An invitation you haven't answered yet.
    public var needsResponse: Bool { myStatus == .pending }

    /// Meeting rooms booked for the event (Google/Exchange add them as attendees).
    public var rooms: [String] {
        attendees.filter { $0.kind == .room }.map(\.displayName)
    }

    public var people: [Attendee] {
        attendees.filter { $0.kind == .person || $0.kind == .group }
    }

    public var organizer: Attendee? {
        attendees.first { $0.isOrganizer }
    }
}

/// Builds a link that opens an event in Google Calendar on the web.
public enum GoogleCalendarLink {
    private static let uidSuffix = "@google.com"

    /// Google Calendar events synced through macOS keep Google's id as their iCalendar UID.
    public static func isGoogleEvent(externalID: String) -> Bool {
        externalID.hasSuffix(uidSuffix)
    }

    /// Opens the event itself when it belongs to the account's primary calendar (whose title is the
    /// account e-mail, needed to build Google's `eid`). Other calendars open the event's day instead.
    public static func url(externalID: String, calendarTitle: String, start: Date, isRecurring: Bool) -> URL? {
        guard isGoogleEvent(externalID: externalID) else { return nil }

        if let eid = eventID(externalID: externalID, calendarTitle: calendarTitle, start: start, isRecurring: isRecurring) {
            return URL(string: "https://calendar.google.com/calendar/event?eid=\(eid)")
        }

        let day = Calendar.current.dateComponents([.year, .month, .day], from: start)
        guard let year = day.year, let month = day.month, let date = day.day else { return nil }
        return URL(string: "https://calendar.google.com/calendar/r/day/\(year)/\(month)/\(date)")
    }

    /// Google's `eid`: base64url of "<event id> <calendar e-mail>", confirmed against a real invitation.
    /// Only the primary calendar's title is its e-mail, so other calendars can't be addressed.
    private static func eventID(externalID: String, calendarTitle: String, start: Date, isRecurring: Bool) -> String? {
        guard isGoogleEvent(externalID: externalID), calendarTitle.contains("@") else { return nil }
        var eventID = String(externalID.dropLast(uidSuffix.count))
        if isRecurring {
            eventID += "_" + utcStamp(start)
        }
        return Data("\(eventID) \(calendarTitle)".utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Google suffixes recurring instance ids with their original start, e.g. `_20261016T130000Z`.
    private static func utcStamp(_ date: Date) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d%02d%02dT%02d%02d%02dZ",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0
        )
    }
}
