import Foundation
import Testing

@testable import CalenbarCore

struct DayOffTests {
    @Test func recognizesTimeOffPhrasesInBothLanguages() {
        #expect(DayOffDetector.kind(title: "Out of office", isHolidayCalendar: false) == .timeOff)
        #expect(DayOffDetector.kind(title: "Ana OOO", isHolidayCalendar: false) == .timeOff)
        #expect(DayOffDetector.kind(title: "PTO - beach", isHolidayCalendar: false) == .timeOff)
        #expect(DayOffDetector.kind(title: "Vacaciones 🌴", isHolidayCalendar: false) == .timeOff)
        #expect(DayOffDetector.kind(title: "Día libre", isHolidayCalendar: false) == .timeOff)
    }

    @Test func holidaysComeFromMarkedCalendarsOrExplicitWords() {
        #expect(DayOffDetector.kind(title: "Día de la Raza", isHolidayCalendar: true) == .holiday)
        #expect(DayOffDetector.kind(title: "Mother's Day", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Bank holiday", isHolidayCalendar: false) == .holiday)
        #expect(DayOffDetector.kind(title: "Feriado puente", isHolidayCalendar: false) == .holiday)
    }

    @Test func timeOffInTheCompanysOtherLanguages() {
        for title in ["Urlaub", "Vakantie 🏖", "Congés", "Férias", "In ferie", "Ferie", "Urlop", "Afwezig", "Krank"] {
            #expect(DayOffDetector.kind(title: title, isHolidayCalendar: false) == .timeOff, "\(title)")
        }
        // Weekday abbreviations and school terms are not days off.
        #expect(DayOffDetector.kind(title: "Fri standup", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Semester planning", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Geburtstag Lena", isHolidayCalendar: false) == nil)
    }

    @Test func holidayCalendarsAreRecognisedByName() {
        #expect(DayOffDetector.looksLikeHolidayCalendar("Holidays in Argentina"))
        #expect(DayOffDetector.looksLikeHolidayCalendar("Festivos en Estados Unidos"))
        #expect(DayOffDetector.looksLikeHolidayCalendar("US Holidays"))
        #expect(DayOffDetector.looksLikeHolidayCalendar("Feiertage in Deutschland"))
        #expect(DayOffDetector.looksLikeHolidayCalendar("Feestdagen in Nederland"))
        #expect(DayOffDetector.looksLikeHolidayCalendar("Jours fériés en France"))
        #expect(DayOffDetector.looksLikeHolidayCalendar("Helligdage i Danmark"))
        #expect(!DayOffDetector.looksLikeHolidayCalendar("Personales"))
        #expect(!DayOffDetector.looksLikeHolidayCalendar("me@example.com"))
    }

    @Test func shortMeetingsAreNeverTimeOff() {
        let start = Fixture.at(14, 0)
        let short = Fixture.event("Vacation planning", start, start.addingTimeInterval(1_800))
        let halfDay = Fixture.event("PTO afternoon", start, start.addingTimeInterval(4 * 3_600))
        let allDay = Fixture.event("Vacaciones", start, start.addingTimeInterval(86_400), isAllDay: true)
        #expect(short.dayOff(holidayCalendars: []) == nil)
        #expect(halfDay.dayOff(holidayCalendars: []) == .timeOff)
        #expect(allDay.dayOff(holidayCalendars: []) == .timeOff)
        #expect(DayOffDetector.kind(title: "Leave feedback on the RFC", isHolidayCalendar: false) == nil)
    }

    @Test func birthdaysAndOrdinaryTitlesAreNotDaysOff() {
        #expect(DayOffDetector.kind(title: "Cumpleaños de Braian Franco.", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Birthday: Tomás (PTO manager)", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "New laptop setup", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Photo review", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Weekly Sync", isHolidayCalendar: false) == nil)
    }
}
