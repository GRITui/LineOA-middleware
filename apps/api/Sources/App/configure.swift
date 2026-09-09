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

    if let token = Environment.get("LINE_CHANNEL_ACCESS_TOKEN"), !token.isEmpty {
        app.lineMessaging = LiveLineMessagingClient(client: app.client, channelAccessToken: token)
    } else {
        app.lineMessaging = NoopLineMessagingClient()
    }

    // One lean scheduled job covers all three reminder windows. See issue #29.
    if app.environment != .testing {
        app.eventLoopGroup.any().scheduleRepeatedAsyncTask(initialDelay: .seconds(30), delay: .seconds(60)) { _ in
            let promise = app.eventLoopGroup.any().makePromise(of: Void.self)
            promise.completeWithTask {
                await ReminderService.run(db: app.db, client: app.lineMessaging, logger: app.logger)
            }
            return promise.futureResult
        }
    }

    try routes(app)
}
