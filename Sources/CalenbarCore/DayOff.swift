import Foundation

/// A day that isn't a workday: your own time off, or a public holiday.
public enum DayOffKind: Sendable, Hashable {
    case timeOff
    case holiday
}

/// Spots time off from the words people and calendar apps actually use, in the languages of a
/// company spread over Europe and the Americas (English, Spanish, Portuguese, German, Dutch, French,
/// Italian, Danish, Swedish, Norwegian, Polish), whole words only ("laptop" is not PTO).
/// Holidays come from holiday calendars, recognised by name and adjustable per calendar in Settings;
/// the feeds mix public holidays with observances (Halloween, Mother's Day) and people do want those
/// days to stand out too.
public enum DayOffDetector {
    private static let timeOff = [
        // English
        "out of office", "ooo", "oof", "pto", "vacation", "vacations", "day off", "time off", "annual leave", "sick day",
        "sick leave", "on leave",
        // Spanish
        "vacaciones", "fuera de la oficina", "dia libre", "dias libres", "licencia",
        // Portuguese
        "ferias", "folga", "fora do escritorio", "ausente",
        // German
        "urlaub", "abwesend", "krank", "frei",
        // Dutch
        "vakantie", "verlof", "afwezig", "vrij", "vrije dag", "ziek",
        // French
        "conge", "conges", "vacances", "absent", "absente", "rtt",
        // Italian
        "ferie", "assente", "malattia",
        // Danish, Swedish, Norwegian ("fri" alone collides with Friday, "semester" with school terms)
        "fridag", "sygedag", "sjuk", "ledighet",
        // Polish
        "urlop", "wolne",
    ]
    private static let holiday = [
        "holiday", "bank holiday", "public holiday", "feriado", "festivo", "feiertag", "feestdag", "jour ferie",
        "festivita", "helligdag", "helgdag", "swieto",
    ]
    /// Someone's birthday is never your day off, whatever their name is.
    private static let birthday = [
        "birthday", "cumpleanos", "cumple", "aniversario", "geburtstag", "verjaardag", "anniversaire", "compleanno",
        "fodselsdag", "urodziny",
    ]

    private static let holidayCalendar = [
        "holiday", "holidays", "feriado", "feriados", "festivo", "festivos", "feiertage", "feestdagen", "jours feries",
        "festivita", "helligdage", "helligdager", "helgdagar", "swieta",
    ]

    /// "Holidays in Argentina", "Feiertage in Deutschland", "Feestdagen in Nederland", "Jours fériés en
    /// France": how Apple and Google name the holiday feeds in each language. The default for whether a
    /// calendar counts as holidays; the user can override it.
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
    /// Time off or a holiday, given which calendars count as holiday calendars.
    public func dayOff(holidayCalendars: Set<String>) -> DayOffKind? {
        holidayCalendars.contains(calendarID) ? .holiday : titleDayOff
    }
}
