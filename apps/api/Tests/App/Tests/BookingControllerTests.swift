import XCTVapor
@testable import App

final class BookingControllerTests: XCTestCase {

    var app: Application!

    override func setUpWithError() throws {
        app = try Application.testable()
        // Migrate the test DB (in‑memory SQLite or a dedicated Postgres container)
        try app.autoMigrate().wait()
    }

    override func tearDownWithError() throws {
        app.shutdown()
    }

    func testDuplicateBookingReturns409() throws {
        let customerId = UUID()
        let sessionId = UUID()
        let payload = BookingController.CreateRequest(customerID: customerId, sessionID: sessionId)

        try app.test(.POST, "/bookings", beforeRequest: { req in
            try req.content.encode(payload)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
        })

        try app.test(.POST, "/bookings", beforeRequest: { req in
            try req.content.encode(payload)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .conflict)
            let json = try res.content.decode([String: String].self)
            XCTAssertEqual(json["reason"], "Booking already exists for this customer and session")
        })
    }
}