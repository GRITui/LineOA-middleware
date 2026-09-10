import Fluent
import FluentPostgresDriver
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

            // Take a row-level lock on the session BEFORE reading bookedCount so a second
            // concurrent transaction for the same session blocks here until the first one
            // commits, then observes the up-to-date bookedCount/status instead of racing on
            // a stale read (see issue: race condition on booking capacity).
            guard let sqlDB = db as? any SQLDatabase else {
                throw Abort(.internalServerError, reason: "Database does not support row locking")
            }
            try await sqlDB.raw("SELECT id FROM sessions WHERE id = \(bind: input.sessionID) FOR UPDATE").run()

            guard let session = try await Session.find(input.sessionID, on: db) else {
                throw Abort(.notFound, reason: "Session not found")
            }
            guard !Self.hasEnded(session) else {
                throw Abort(.conflict, reason: "Session has already ended")
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
