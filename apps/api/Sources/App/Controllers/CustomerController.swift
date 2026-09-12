import Fluent
import Vapor

// POST /customers/resolve — see GitHub issue #11 (LINE Login integration).
// Resolves an existing Customer by LINE userId, or creates one if none exists yet.
// Idempotent: safe to call every time the Mini App opens.
struct CustomerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("customers", "resolve", use: resolve)
        routes.get("customers", use: index)
    }

    struct ResolveRequest: Content {
        var lineUserID: String
        var name: String
    }

    func resolve(req: Request) async throws -> Customer {
        let input = try req.content.decode(ResolveRequest.self)
        guard !input.lineUserID.isEmpty else {
            throw Abort(.badRequest, reason: "lineUserID is required")
        }

        if let existing = try await Customer.query(on: req.db)
            .filter(\.$lineUserID == input.lineUserID)
            .first()
        {
            // Keep the display name in sync with LINE in case the user renamed themselves.
            if existing.name != input.name, !input.name.isEmpty {
                existing.name = input.name
                try await existing.save(on: req.db)
            }
            return existing
        }

        let customer = Customer(lineUserID: input.lineUserID, name: input.name)
        try await customer.save(on: req.db)
        return customer
    }

    func index(req: Request) async throws -> [CustomerWithBookingCount] {
        let customers = try await Customer.query(on: req.db).all()
        var result = [CustomerWithBookingCount]()
        result.reserveCapacity(customers.count)
        for customer in customers {
            let bookingCount = try await Booking.query(on: req.db)
                .filter(\.$customer.$id == customer.requireID())
                .count()
            result.append(CustomerWithBookingCount(
                id: try customer.requireID(),
                lineUserID: customer.lineUserID,
                name: customer.name,
                bookingCount: bookingCount
            ))
        }
        return result
    }
}

struct CustomerWithBookingCount: Content {
    var id: UUID
    var lineUserID: String
    var name: String
    var bookingCount: Int
}
