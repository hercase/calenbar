import Foundation

/// A day that isn't a workday: your own time off, or a public holiday.
public enum DayOffKind: Sendable, Hashable {
    case timeOff
    case holiday
}

/// Spots time off and holidays from the words people and calendar apps actually use, in English and
/// Spanish. Whole words only, so "laptop" never counts as PTO.
public enum DayOffDetector {
    private static let timeOff = [
        "out of office", "ooo", "oof", "pto", "vacation", "vacations", "vacaciones", "fuera de la oficina", "day off",
        "time off", "dia libre", "dias libres", "licencia", "sick day", "sick leave", "franco",
    ]
    private static let holiday = ["holiday", "holidays", "bank holiday", "feriado", "feriados", "festivo", "festivos"]

    public static func kind(title: String, calendarTitle: String) -> DayOffKind? {
        let calendarWords = words(calendarTitle)
        if holiday.contains(where: { calendarWords.contains(" \($0) ") }) {
            return .holiday
        }
        let titleWords = words(title)
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
    /// Time off or a holiday, judged from the event's title and its calendar's name.
    public var dayOff: DayOffKind? {
        DayOffDetector.kind(title: title, calendarTitle: calendarTitle)
    }
}
