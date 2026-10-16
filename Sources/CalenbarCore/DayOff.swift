import Foundation

/// A day that isn't a workday: your own time off, or a public holiday.
public enum DayOffKind: Sendable, Hashable {
    case timeOff
    case holiday
}

/// Spots time off from the words people and calendar apps actually use, in English and Spanish,
/// whole words only ("laptop" is not PTO). Holidays come from holiday calendars, recognised by
/// name and adjustable per calendar in Settings; the feeds mix public holidays with observances
/// (Halloween, Mother's Day) and people do want those days to stand out too.
public enum DayOffDetector {
    private static let timeOff = [
        "out of office", "ooo", "oof", "pto", "vacation", "vacations", "vacaciones", "fuera de la oficina", "day off",
        "time off", "dia libre", "dias libres", "licencia", "sick day", "sick leave",
    ]
    private static let holiday = ["holiday", "bank holiday", "public holiday", "feriado", "festivo"]
    /// Someone's birthday is never your day off, whatever their name is.
    private static let birthday = ["birthday", "cumpleanos", "cumple"]

    private static let holidayCalendar = ["holiday", "holidays", "feriado", "feriados", "festivo", "festivos"]

    /// "Holidays in Argentina", "Festivos en Estados Unidos", "US Holidays": the usual names of the
    /// holiday feeds. The default for whether a calendar counts as holidays; the user can override it.
    public static func looksLikeHolidayCalendar(_ calendarTitle: String) -> Bool {
        let calendarWords = words(calendarTitle)
        return holidayCalendar.contains { calendarWords.contains(" \($0) ") }
    }

    public static func kind(title: String, isHolidayCalendar: Bool) -> DayOffKind? {
        if isHolidayCalendar {
            return .holiday
        }
        let titleWords = words(title)
        if birthday.contains(where: { titleWords.contains(" \($0) ") }) {
            return nil
        }
        if holiday.contains(where: { titleWords.contains(" \($0) ") }) {
            return .holiday
        }
        if timeOff.contains(where: { titleWords.contains(" \($0) ") }) {
            return .timeOff
        }
        return nil
    }

    /// Lowercased, accents dropped, punctuation turned into spaces, padded so phrases match whole words.
    private static func words(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let letters = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return " " + String(letters).split(separator: " ").joined(separator: " ") + " "
    }
}

extension CalendarEvent {
    /// Time off or a holiday, given which calendars the user marked as holiday calendars.
    public func dayOff(holidayCalendars: Set<String>) -> DayOffKind? {
        DayOffDetector.kind(title: title, isHolidayCalendar: holidayCalendars.contains(calendarID))
    }
}
