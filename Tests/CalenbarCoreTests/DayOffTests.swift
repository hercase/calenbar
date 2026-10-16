import Foundation
import Testing

@testable import CalenbarCore

struct DayOffTests {
    @Test func recognizesTimeOffPhrasesInBothLanguages() {
        #expect(DayOffDetector.kind(title: "Out of office", calendarTitle: "Work") == .timeOff)
        #expect(DayOffDetector.kind(title: "Ana OOO", calendarTitle: "Team") == .timeOff)
        #expect(DayOffDetector.kind(title: "PTO - beach", calendarTitle: "Work") == .timeOff)
        #expect(DayOffDetector.kind(title: "Vacaciones 🌴", calendarTitle: "Personal") == .timeOff)
        #expect(DayOffDetector.kind(title: "Día libre", calendarTitle: "Personal") == .timeOff)
    }

    @Test func recognizesHolidaysByCalendarOrTitle() {
        #expect(DayOffDetector.kind(title: "Columbus Day", calendarTitle: "US Holidays") == .holiday)
        #expect(DayOffDetector.kind(title: "Día de la Raza", calendarTitle: "Feriados de Argentina") == .holiday)
        #expect(DayOffDetector.kind(title: "Bank holiday", calendarTitle: "Work") == .holiday)
    }

    @Test func wholeWordsOnly() {
        #expect(DayOffDetector.kind(title: "New laptop setup", calendarTitle: "Work") == nil)
        #expect(DayOffDetector.kind(title: "Photo review", calendarTitle: "Work") == nil)
        #expect(DayOffDetector.kind(title: "Weekly Sync", calendarTitle: "me@example.com") == nil)
    }
}
