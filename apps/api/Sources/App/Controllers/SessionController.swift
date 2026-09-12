import Fluent
import Vapor

// Admin CRUD for Sessions, plus per-session bookings/customers — see GitHub issue #28.
// Unlike AvailabilityController (public, open-sessions-only), this surface is meant for
// the native admin app: it lists every session regardless of status, and lets an admin
// create/edit sessions and inspect who booked into one.
struct SessionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let sessions = routes.grouped("sessions")
        sessions.get(use: index)
        sessions.post(use: create)
        sessions.group(":sessionID") { session in
            session.delete(use: delete)
            session.put(use: update)
            session.get("bookings", use: bookings)
        }
    }

    struct SessionInput: Content {
        var title: String
        var date: Date
        var startTime: String
        var endTime: String
        var capacity: Int
        var status: SessionStatus?
    }

    func index(req: Request) async throws -> [Session] {
        try await Session.query(on: req.db)
            .sort(\.$date)
            .all()
    }

    func create(req: Request) async throws -> Session {
        let input = try req.content.decode(SessionInput.self)
        let session = Session(
            title: input.title,
            date: input.date,
            startTime: input.startTime,
            endTime: input.endTime,
            capacity: input.capacity,
            status: input.status ?? .open
        )
        try await session.save(on: req.db)
        return session
    }

    func update(req: Request) async throws -> Session {
        guard let sessionID = req.parameters.get("sessionID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }
        guard let session = try await Session.find(sessionID, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let input = try req.content.decode(SessionInput.self)
        session.title = input.title
        session.date = input.date
        session.startTime = input.startTime
        session.endTime = input.endTime
        session.capacity = input.capacity
        session.status = input.status ?? session.status
        try await session.save(on: req.db)
        return session
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let sessionID = req.parameters.get("sessionID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }
        guard let session = try await Session.find(sessionID, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let bookingCount = try await Booking.query(on: req.db)
            .filter(\.$session.$id == sessionID)
            .count()

        if bookingCount > 0 {
            throw Abort(.conflict, reason: "Cannot delete session: \(bookingCount) booking(s) exist")
        }

        try await session.delete(on: req.db)
        return .noContent
    }

    struct BookingWithCustomer: Content {
        var bookingID: UUID
        var status: BookingStatus
        var createdDate: Date?
        var customerID: UUID
        var customerName: String
        var customerLineUserID: String
        var customerPhone: String?
        var customerEmail: String?
        var reminder24Sent: Bool
        var reminder2Sent: Bool
        var reminder15Sent: Bool
    }

    func bookings(req: Request) async throws -> [BookingWithCustomer] {
        guard let sessionID = req.parameters.get("sessionID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }
        guard try await Session.find(sessionID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let bookings = try await Booking.query(on: req.db)
            .filter(\.$session.$id == sessionID)
            .with(\.$customer)
            .sort(\.$createdDate)
            .all()

        return try bookings.map { booking in
            BookingWithCustomer(
                bookingID: try booking.requireID(),
                status: booking.status,
                createdDate: booking.createdDate,
                customerID: try booking.customer.requireID(),
                customerName: booking.customer.name,
                customerLineUserID: booking.customer.lineUserID,
                customerPhone: booking.customer.phone,
                customerEmail: booking.customer.email,
                reminder24Sent: booking.reminder24Sent,
                reminder2Sent: booking.reminder2Sent,
                reminder15Sent: booking.reminder15Sent
            )
        }
    }
}
