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
    /// Other calendars that carry a copy of this event (a mirror into a work calendar, a shared team
    /// calendar); those copies are folded into this one by `deduplicated`.
    public var alsoIn: [String] = []
    /// Found once here: link detection scans the notes, and every surface reads it many times a minute.
    public let meetingLink: MeetingLink?
    /// What the title alone says about the day (time off, a holiday); the calendar may add to it.
    public let titleDayOff: DayOffKind?

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
        meetingLink = MeetingLinkDetector.detect(url: url, location: location, notes: notes)
        // Time off is a day or at least a half day; a short meeting with "vacation" in its title isn't.
        let kind = DayOffDetector.kind(title: title, isHolidayCalendar: false)
        let longEnough = isAllDay || end.timeIntervalSince(start) >= 4 * 3_600
        titleDayOff = kind == .timeOff && !longEnough ? nil : kind
    }

    /// Stable key for a single occurrence, used to persist Hide/Mute.
    /// Includes the start so hiding one occurrence of a recurring event leaves the others visible.
    public var key: String {
        "\(externalID)|\(Int(start.timeIntervalSince1970))"
    }

    public func isOngoing(at now: Date) -> Bool {
        start <= now && now < end
    }

    /// The same event often appears in several calendars: shared and team calendars, or a personal
    /// event mirrored into a work one. Keeps one copy per time slot when the titles match once tags
    /// and emoji are stripped, or when one copy is just a placeholder ("Busy", "Ocupado"). Prefers
    /// the copy with a real title, then a meeting link, then attendees. Order of first appearance is
    /// preserved, and the kept copy lists the other calendars in `alsoIn`.
    public static func deduplicated(_ events: [Self]) -> [Self] {
        var kept: [Self] = []
        for event in events {
            guard let index = kept.firstIndex(where: { $0.isCopy(of: event) }) else {
                kept.append(event)
                continue
            }
            let current = kept[index]
            var winner = event.duplicatePreference > current.duplicatePreference ? event : current
            let loser = winner.id == event.id ? current : event
            winner.alsoIn = (current.alsoIn + event.alsoIn + [loser.calendarTitle])
                .filter { $0 != winner.calendarTitle }
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            kept[index] = winner
        }
        return kept
    }

    private func isCopy(of other: Self) -> Bool {
        guard start == other.start, end == other.end, isAllDay == other.isAllDay else { return false }
        let mine = Self.comparableTitle(title)
        let theirs = Self.comparableTitle(other.title)
        return mine == theirs || Self.isPlaceholder(mine) || Self.isPlaceholder(theirs)
    }

    /// What mirroring tools write when they hide the real title.
    private static let placeholders: Set<String> = [
        "busy", "ocupado", "ocupada", "personal", "private", "privado", "privada", "personal commitment",
        "blocked", "bloqueado", "unavailable", "no disponible", "(no title)", "",
    ]

    private static func isPlaceholder(_ comparableTitle: String) -> Bool {
        placeholders.contains(comparableTitle)
    }

    /// Lowercased, trimmed, with leading tags like "[Personal]", "(copy)" or "🔒" removed.
    private static func comparableTitle(_ title: String) -> String {
        var text = Substring(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        while let first = text.first {
            if first == "[" || first == "(" {
                let close: Character = first == "[" ? "]" : ")"
                guard let end = text.firstIndex(of: close) else { break }
                text = text[text.index(after: end)...]
            } else if first.isLetter || first.isNumber {
                break
            } else {
                text = text.dropFirst()
            }
            text = text.drop { $0.isWhitespace || $0 == ":" || $0 == "-" }
        }
        return String(text)
    }

    /// A real title beats a placeholder; then a meeting link; then attendees.
    private var duplicatePreference: Int {
        (Self.isPlaceholder(Self.comparableTitle(title)) ? 0 : 4) + (meetingLink == nil ? 0 : 2) + (hasOtherAttendees ? 1 : 0)
    }
}
