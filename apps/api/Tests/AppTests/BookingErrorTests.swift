import Vapor
import XCTest
@testable import App

final class BookingErrorTests: XCTestCase {
    func testDuplicateMapsToHTTP409WithExpectedReason() {
        let error = BookingError.duplicate
        XCTAssertEqual(error.status, .conflict)
        XCTAssertEqual(error.reason, "Booking already exists for this customer and session")
    }

    func testDuplicateConformsToAbortError() {
        // Vapor encodes AbortError via its `ResponseEncodable` error path:
        // assert the conformance so the type can't silently regress to a
        // non-typed error that would surface as a 500.
        let error: AbortError = BookingError.duplicate
        XCTAssertEqual(error.status, .conflict)
    }
}