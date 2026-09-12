import Fluent
import FluentPostgresDriver
import Vapor

// POST /bookings — see GitHub issue #10.
// POST /bookings/manual — walk-in / phone booking from the admin panel,
// see TSK-401. Creates a guest customer on the fly; shares the same
// row-locked transaction core so a LINE booking racing a manual one for
// the last slot still yields exactly one 201 and one 409.
struct BookingController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("bookings", use: create)
        routes.post("bookings", "manual", use: createManual)
    }

    struct CreateRequest: Content {
        var customerID: UUID
        var sessionID: UUID
    }

    struct ManualRequest: Content {
        var sessionID: UUID
        var name: String
        var phone: String?
    }

    /// Guest LINE user IDs are namespaced so they can never collide with real
    /// LINE user IDs (line_user_id is unique — see CreateCustomer).
    static func makeGuestLineUserID() -> String {
        "guest:\(UUID().uuidString)"
    }

    func create(req: Request) async throws -> Booking {
        let input = try req.content.decode(CreateRequest.self)

        let (booking, customer, session) = try await req.db.transaction { db in
            try await Self.book(customerID: input.customerID, sessionID: input.sessionID, source: "line", on: db)
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

    func createManual(req: Request) async throws -> Booking {
        let input = try req.content.decode(ManualRequest.self)
        guard !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Name is required")
        }

        let booking = try await req.db.transaction { db -> Booking in
            let guest = Customer(
                lineUserID: Self.makeGuestLineUserID(),
                name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: input.phone
            )
            try await guest.save(on: db)
            let (booking, _, _) = try await Self.book(
                customerID: try guest.requireID(),
                sessionID: input.sessionID,
                source: "admin",
                on: db
            )
            return booking
        }

        // No LINE push: guest lineUserID is not a real LINE user. The booking
        // itself already committed; nothing best-effort to do here.
        return booking
    }

    /// Shared booking core: capacity check + write happen inside one transaction
    /// so two concurrent requests for the last remaining slot can't both succeed.
    static func book(customerID: UUID, sessionID: UUID, source: String, on db: Database) async throws -> (Booking, Customer, Session) {
        guard let customer = try await Customer.find(customerID, on: db) else {
            throw Abort(.notFound, reason: "Customer not found")
        }

        // Take a row-level lock on the session BEFORE reading bookedCount so a second
        // concurrent transaction for the same session blocks here until the first one
        // commits, then observes the up-to-date bookedCount/status instead of racing on
        // a stale read (see issue: race condition on booking capacity).
        guard let sqlDB = db as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "Database does not support row locking")
        }
        try await sqlDB.raw("SELECT id FROM sessions WHERE id = \(bind: sessionID) FOR UPDATE").run()

        guard let session = try await Session.find(sessionID, on: db) else {
            throw Abort(.notFound, reason: "Session not found")
        }
        guard !Self.hasEnded(session) else {
            throw Abort(.conflict, reason: "Session has already ended")
        }
        guard session.status == .open, session.bookedCount < session.capacity else {
            throw Abort(.conflict, reason: "Session is full")
        }

        let booking = Booking(customerID: customerID, sessionID: sessionID, source: source)
        do {
            try await booking.save(on: db)
        } catch let dbError as DatabaseError where dbError.isUniqueConstraintViolation {
            // Duplicate (customer_id, session_id) — surface as a clean 409
            // instead of letting the raw PostgresError bubble up as a 500.
            throw BookingError.duplicate
        }

        session.bookedCount += 1
        if session.bookedCount >= session.capacity {
            session.status = .full
        }
        try await session.save(on: db)

        return (booking, customer, session)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private static func confirmationText(for session: Session) -> String {
        "Booking confirmed: \(session.title) on \(dateFormatter.string(from: session.date)), \(session.startTime)-\(session.endTime)."
    }

    /// True if the session's date + end time is already in the past, relative to `now`.
    /// `session.date` stores only a calendar day (UTC midnight); `endTime` is an "HH:mm"
    /// string. If `endTime` can't be parsed, fall back to end-of-day so we don't
    /// accidentally reject a session with an unusual time format.
    private static func hasEnded(_ session: Session, now: Date = Date()) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = calendar.dateComponents([.year, .month, .day], from: session.date)
        let timeParts = session.endTime.split(separator: ":").compactMap { Int($0) }
        if timeParts.count >= 2 {
            components.hour = timeParts[0]
            components.minute = timeParts[1]
            components.second = 0
        } else {
            components.hour = 23
            components.minute = 59
            components.second = 59
        }

        guard let sessionEnd = calendar.date(from: components) else {
            return false
        }
        return sessionEnd < now
    }
}
