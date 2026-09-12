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
    app.migrations.add(AddBookingSourceAndNote())

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

    // See the CORS origin note in docs/db-security.md issue context: the LIFF
    // Mini App is served from a different origin than the API in every real
    // deployment (LINE webview -> API host), so the browser needs explicit
    // CORS clearance for availability/booking calls. POC: allow any origin.
    let cors = CORSMiddleware(configuration: CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS],
        allowedHeaders: ["content-type", "authorization", "x-line-signature"],
        cacheExpiration: 86400
    ))
    app.middleware.use(cors, at: .beginning)

    try routes(app)
}
