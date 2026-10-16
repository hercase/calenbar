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

    @Test func birthdaysAndOrdinaryTitlesAreNotDaysOff() {
        #expect(DayOffDetector.kind(title: "Cumpleaños de Braian Franco.", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Birthday: Tomás (PTO manager)", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "New laptop setup", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Photo review", isHolidayCalendar: false) == nil)
        #expect(DayOffDetector.kind(title: "Weekly Sync", isHolidayCalendar: false) == nil)
    }
}
