import Fluent
import Vapor

// See GitHub issue #29. One lean scheduled job covering all three reminder
// windows (T-24h / T-2h / T-15min), superseding #19/#20/#21.
enum ReminderService {
    private static let timeOfDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    static func sessionStart(for session: Session) -> Date? {
        guard let timeOfDay = timeOfDayFormatter.date(from: session.startTime) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: session.date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOfDay)
        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged)
    }

    static func reminderText(window: String, session: Session) -> String {
        "Reminder: \(session.title) starts in \(window) on \(displayDateFormatter.string(from: session.date)), \(session.startTime)-\(session.endTime)."
    }

    /// Sends any due reminders and marks them sent. Best-effort per booking: a push failure
    /// or save failure for one booking is logged and does not stop the rest of the run.
    static func run(db: Database, client: LineMessagingClient, logger: Logger, now: Date = Date()) async {
        let bookings: [Booking]
        do {
            bookings = try await Booking.query(on: db)
                .filter(\.$status == .confirmed)
                .with(\.$customer)
                .with(\.$session)
                .all()
        } catch {
            logger.error("Reminder job: failed to load bookings: \(error)")
            return
        }

        for booking in bookings {
            let session = booking.session
            guard let start = sessionStart(for: session), start > now else { continue }
            let secondsUntilStart = start.timeIntervalSince(now)

            if secondsUntilStart <= 24 * 3600, !booking.reminder24Sent {
                await send(window: "24 hours", to: booking, customer: booking.customer, session: session, db: db, client: client, logger: logger) {
                    $0.reminder24Sent = true
                }
            }
            if secondsUntilStart <= 2 * 3600, !booking.reminder2Sent {
                await send(window: "2 hours", to: booking, customer: booking.customer, session: session, db: db, client: client, logger: logger) {
                    $0.reminder2Sent = true
                }
            }
            if secondsUntilStart <= 15 * 60, !booking.reminder15Sent {
                await send(window: "15 minutes", to: booking, customer: booking.customer, session: session, db: db, client: client, logger: logger) {
                    $0.reminder15Sent = true
                }
            }
        }
    }

    private static func send(
        window: String,
        to booking: Booking,
        customer: Customer,
        session: Session,
        db: Database,
        client: LineMessagingClient,
        logger: Logger,
        markSent: (Booking) -> Void
    ) async {
        do {
            try await client.pushMessage(to: customer.lineUserID, text: reminderText(window: window, session: session))
        } catch {
            logger.error("Reminder job: push failed for booking \(booking.id?.uuidString ?? "?") (\(window)): \(error)")
            return
        }
        markSent(booking)
        do {
            try await booking.save(on: db)
        } catch {
            logger.error("Reminder job: failed to persist sent-flag for booking \(booking.id?.uuidString ?? "?") (\(window)): \(error)")
        }
    }
}
