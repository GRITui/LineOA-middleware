import Fluent
import Vapor

// See GitHub issue #6.
final class Customer: Model, Content, @unchecked Sendable {
    static let schema = "customers"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "line_user_id")
    var lineUserID: String

    @Field(key: "name")
    var name: String

    @OptionalField(key: "phone")
    var phone: String?

    @OptionalField(key: "email")
    var email: String?

    @Timestamp(key: "created_date", on: .create)
    var createdDate: Date?

    init() {}

    init(id: UUID? = nil, lineUserID: String, name: String, phone: String? = nil, email: String? = nil) {
        self.id = id
        self.lineUserID = lineUserID
        self.name = name
        self.phone = phone
        self.email = email
    }
}

struct CreateCustomer: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("customers")
            .id()
            .field("line_user_id", .string, .required)
            .unique(on: "line_user_id")
            .field("name", .string, .required)
            .field("phone", .string)
            .field("email", .string)
            .field("created_date", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("customers").delete()
    }
}
