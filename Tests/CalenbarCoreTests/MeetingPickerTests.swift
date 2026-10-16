import Foundation
import Testing

@testable import CalenbarCore

struct MeetingPickerTests {
    private let now = Fixture.at(10, 0)
    private let meet = URL(string: "https://meet.google.com/abc-defg-hij")

    @Test func titleEventWinsWhenItHasALink() {
        let shown = Fixture.event("Sync", Fixture.at(10, 30), Fixture.at(11, 0), url: meet)
        let earlier = Fixture.event("Standup", Fixture.at(9, 45), Fixture.at(10, 15), url: meet)
        #expect(MeetingPicker.next(titleEvent: shown, candidates: [earlier, shown], now: now)?.title == "Sync")
    }

    @Test func fallsBackToTheEarliestUnfinishedMeetingWithALink() {
        let lunch = Fixture.event("Lunch", Fixture.at(10, 0), Fixture.at(11, 0))
        let over = Fixture.event("Old", Fixture.at(8, 0), Fixture.at(9, 0), url: meet)
        let later = Fixture.event("Review", Fixture.at(12, 0), Fixture.at(13, 0), url: meet)
        let soon = Fixture.event("Planning", Fixture.at(11, 0), Fixture.at(12, 0), url: meet)
        let picked = MeetingPicker.next(titleEvent: lunch, candidates: [over, later, soon, lunch], now: now)
        #expect(picked?.title == "Planning")
    }

    @Test func nothingWhenNoMeetingHasALink() {
        let lunch = Fixture.event("Lunch", Fixture.at(10, 0), Fixture.at(11, 0))
        #expect(MeetingPicker.next(titleEvent: lunch, candidates: [lunch], now: now) == nil)
    }
}
