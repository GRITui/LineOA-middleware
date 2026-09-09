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
        let (booking, customer, session) = try await req.db.transaction { db -> (Booking, Customer, Session) in
            guard let customer = try await Customer.find(input.customerID, on: db) else {
                throw Abort(.notFound, reason: "Customer not found")
            }
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

            return (booking, customer, session)
        }

        // Best-effort: a confirmation push failing shouldn't fail the booking that already
        // committed. See issue #15 (acceptance: pushed within a few seconds of booking).
        do {
            try await req.application.lineMessaging.pushMessage(
                to: customer.lineUserID,
                text: Self.confirmationText(for: session)
            )
        } catch {
            req.logger.error("LINE confirmation push failed: \(error)")
        }

        return booking
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private static func confirmationText(for session: Session) -> String {
        "Booking confirmed: \(session.title) on \(dateFormatter.string(from: session.date)), \(session.startTime)-\(session.endTime)."
    }
}
