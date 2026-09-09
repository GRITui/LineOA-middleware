import XCTVapor
@testable import App

final class BookingIntentMatcherTests: XCTestCase {
    func testMatchesEnglishBookingKeyword() {
        XCTAssertTrue(BookingIntentMatcher.isBookingIntent("I'd like to book a session"))
    }

    func testMatchesCaseInsensitively() {
        XCTAssertTrue(BookingIntentMatcher.isBookingIntent("BOOK NOW please"))
    }

    func testMatchesAvailabilityKeyword() {
        XCTAssertTrue(BookingIntentMatcher.isBookingIntent("what slots are available?"))
    }

    func testMatchesThaiBookingKeyword() {
        XCTAssertTrue(BookingIntentMatcher.isBookingIntent("อยากจองคิว"))
    }

    func testDoesNotMatchUnrelatedText() {
        XCTAssertFalse(BookingIntentMatcher.isBookingIntent("thanks for the reminder!"))
    }
}
