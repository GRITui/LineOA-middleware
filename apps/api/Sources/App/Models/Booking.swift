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

    init() {}

    init(id: UUID? = nil, customerID: Customer.IDValue, sessionID: Session.IDValue, status: BookingStatus = .confirmed) {
        self.id = id
        self.$customer.id = customerID
        self.$session.id = sessionID
        self.status = status
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
            .unique(on: "customer_id", "session_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("bookings").delete()
        try await database.enum("booking_status").delete()
    }
}
