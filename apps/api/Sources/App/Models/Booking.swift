import Fluent
import Vapor

// See GitHub issue #8.
enum BookingStatus: String, Codable {
    case confirmed
    case cancelled
}

final class Booking: Model, Content, @unchecked Sendable {
    static let schema = "bookings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "customer_id")
    var customer: Customer

    @Parent(key: "session_id")
    var session: Session

    @Enum(key: "status")
    var status: BookingStatus

    @Timestamp(key: "created_date", on: .create)
    var createdDate: Date?

    @Field(key: "reminder_24h_sent")
    var reminder24Sent: Bool

    @Field(key: "reminder_2h_sent")
    var reminder2Sent: Bool

    @Field(key: "reminder_15min_sent")
    var reminder15Sent: Bool

    // Booking origin: "line" (LIFF / webhook flow) or "admin" (manual
    // walk-in / phone booking from the admin panel). See TSK-401.
    @Field(key: "source")
    var source: String

    @OptionalField(key: "note")
    var note: String?

    init() {}

    init(id: UUID? = nil, customerID: Customer.IDValue, sessionID: Session.IDValue, status: BookingStatus = .confirmed, source: String = "line", note: String? = nil) {
        self.id = id
        self.$customer.id = customerID
        self.$session.id = sessionID
        self.status = status
        self.reminder24Sent = false
        self.reminder2Sent = false
        self.reminder15Sent = false
        self.source = source
        self.note = note
    }
}

struct CreateBooking: AsyncMigration {
    func prepare(on database: Database) async throws {
        let status = try await database.enum("booking_status")
            .case("confirmed")
            .case("cancelled")
            .create()

        try await database.schema("bookings")
            .id()
            .field("customer_id", .uuid, .required, .references("customers", "id"))
            .field("session_id", .uuid, .required, .references("sessions", "id"))
            .field("status", status, .required, .sql(.default("confirmed")))
            .field("created_date", .datetime)
            .field("reminder_24h_sent", .bool, .required, .sql(.default(false)))
            .field("reminder_2h_sent", .bool, .required, .sql(.default(false)))
            .field("reminder_15min_sent", .bool, .required, .sql(.default(false)))
            .unique(on: "customer_id", "session_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("bookings").delete()
        try await database.enum("booking_status").delete()
    }
}

// See TSK-401: tracks booking origin + free-text note for manual bookings.
// Default source "line" backfills existing rows as LINE-originated.
struct AddBookingSourceAndNote: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("bookings")
            .field("source", .string, .required, .sql(.default("line")))
            .field("note", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("bookings")
            .deleteField("source")
            .deleteField("note")
            .update()
    }
}
