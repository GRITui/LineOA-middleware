import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ in "ok" }

    try app.register(collection: AvailabilityController())
    try app.register(collection: BookingController())
    try app.register(collection: ReportController())
}
