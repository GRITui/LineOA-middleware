import Fluent
import FluentPostgresDriver
import Vapor

public func configure(_ app: Application) throws {
    let dbConfig = SQLPostgresConfiguration(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor",
        database: Environment.get("DATABASE_NAME") ?? "lineoa_booking",
        tls: .disable
    )
    app.databases.use(.postgres(configuration: dbConfig), as: .psql)

    app.migrations.add(CreateCustomer())
    app.migrations.add(CreateSession())
    app.migrations.add(CreateBooking())

    try routes(app)
}
