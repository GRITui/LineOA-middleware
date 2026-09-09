import Fluent
import Vapor

// POST /bookings — see GitHub issue #10.
struct BookingController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("bookings", use: create)
    }

    struct CreateRequest: Content {
        var customerID: UUID
        var sessionID: UUID
    }

    func create(req: Request) async throws -> Booking {
        let input = try req.content.decode(CreateRequest.self)

        // Capacity check + write happen inside one transaction so two concurrent
        // requests for the last remaining slot can't both succeed.
        return try await req.db.transaction { db in
            guard let session = try await Session.find(input.sessionID, on: db) else {
                throw Abort(.notFound, reason: "Session not found")
            }
            guard session.status == .open, session.bookedCount < session.capacity else {
                throw Abort(.conflict, reason: "Session is full")
            }

            let booking = Booking(customerID: input.customerID, sessionID: input.sessionID)
            try await booking.save(on: db)

            session.bookedCount += 1
            if session.bookedCount >= session.capacity {
                session.status = .full
            }
            try await session.save(on: db)

            return booking
        }
    }
}
