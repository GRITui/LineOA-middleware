import XCTVapor
@testable import App

// TSK-401: guest-customer + source coverage that needs no database
// (CI has no Postgres service; the transactional race behavior is covered
// live against staging instead).
final class ManualBookingTests: XCTestCase {
    func testGuestLineUserIDIsNamespaced() {
        let id = BookingController.makeGuestLineUserID()
        XCTAssertTrue(id.hasPrefix("guest:"))
        XCTAssertGreaterThan(id.count, "guest:".count)
    }

    func testGuestLineUserIDsAreUnique() {
        let ids = (0..<100).map { _ in BookingController.makeGuestLineUserID() }
        XCTAssertEqual(Set(ids).count, 100)
    }

    func testBookingDefaultsToLineSource() {
        let booking = Booking(
            customerID: UUID(),
            sessionID: UUID()
        )
        XCTAssertEqual(booking.source, "line")
        XCTAssertNil(booking.note)
    }

    func testBookingAcceptsAdminSource() {
        let booking = Booking(
            customerID: UUID(),
            sessionID: UUID(),
            source: "admin"
        )
        XCTAssertEqual(booking.source, "admin")
    }
}
