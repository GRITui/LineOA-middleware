import XCTVapor
@testable import App

final class ReminderServiceTests: XCTestCase {
    func testSessionStartCombinesDateAndStartTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!

        let session = Session(title: "Yoga", date: day, startTime: "14:30", endTime: "15:30", capacity: 10)

        let start = try XCTUnwrap(ReminderService.sessionStart(for: session))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 10)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    func testSessionStartReturnsNilForMalformedStartTime() {
        let session = Session(title: "Yoga", date: Date(), startTime: "not-a-time", endTime: "15:30", capacity: 10)
        XCTAssertNil(ReminderService.sessionStart(for: session))
    }

    func testReminderTextIncludesWindowAndSessionDetails() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let session = Session(title: "Yoga", date: day, startTime: "14:30", endTime: "15:30", capacity: 10)

        let text = ReminderService.reminderText(window: "24 hours", session: session)
        XCTAssertTrue(text.contains("24 hours"))
        XCTAssertTrue(text.contains("Yoga"))
        XCTAssertTrue(text.contains("14:30-15:30"))
    }
}
