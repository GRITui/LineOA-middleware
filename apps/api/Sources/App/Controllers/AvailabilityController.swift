import Fluent
import Vapor

// GET /availability — see GitHub issue #9.
struct AvailabilityController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("availability", use: index)
    }

    func index(req: Request) async throws -> [Session] {
        try await Session.query(on: req.db)
            .filter(\.$status == .open)
            .sort(\.$date)
            .all()
    }
}
