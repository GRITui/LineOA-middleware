import Fluent
import Vapor

// See GitHub issue #7.
enum SessionStatus: String, Codable {
    case open
    case full
}

final class Session: Model, Content, @unchecked Sendable {
    static let schema = "sessions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "date")
    var date: Date

    @Field(key: "start_time")
    var startTime: String

    @Field(key: "end_time")
    var endTime: String

    @Field(key: "capacity")
    var capacity: Int

    @Field(key: "booked_count")
    var bookedCount: Int

    @Enum(key: "status")
    var status: SessionStatus

    init() {}

    init(id: UUID? = nil, title: String, date: Date, startTime: String, endTime: String, capacity: Int, bookedCount: Int = 0, status: SessionStatus = .open) {
        self.id = id
        self.title = title
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.capacity = capacity
        self.bookedCount = bookedCount
        self.status = status
    }
}

struct CreateSession: AsyncMigration {
    func prepare(on database: Database) async throws {
        let status = try await database.enum("session_status")
            .case("open")
            .case("full")
            .create()

        try await database.schema("sessions")
            .id()
            .field("title", .string, .required)
            .field("date", .date, .required)
            .field("start_time", .string, .required)
            .field("end_time", .string, .required)
            .field("capacity", .int, .required)
            .field("booked_count", .int, .required, .sql(.default(0)))
            .field("status", status, .required, .sql(.default("open")))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
        try await database.enum("session_status").delete()
    }
}
