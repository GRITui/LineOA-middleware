import Fluent
import Vapor

// Pure formatting helpers, split out from ReportController so they're
// unit-testable without a database (CI has no Postgres service).
enum ReportFormatting {
    static func utilization(bookedCount: Int, capacity: Int) -> Double {
        capacity > 0 ? Double(bookedCount) / Double(capacity) : 0
    }

    static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

// Lean bookings/capacity report endpoints — see GitHub issue #30.
// No BI tool dependency: JSON by default, CSV via ?format=csv, good enough to
// drop straight into a spreadsheet or a simple chart.
struct ReportController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let reports = routes.grouped("reports")
        reports.get("bookings-by-day", use: bookingsByDay)
        reports.get("capacity-utilization", use: capacityUtilization)
    }

    struct FormatQuery: Content {
        var format: String?
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    struct BookingsByDayRow: Content {
        var date: String
        var count: Int
    }

    func bookingsByDay(req: Request) async throws -> Response {
        let bookings = try await Booking.query(on: req.db)
            .filter(\.$status == .confirmed)
            .all()

        var counts: [String: Int] = [:]
        for booking in bookings {
            guard let createdDate = booking.createdDate else { continue }
            let day = Self.dayFormatter.string(from: createdDate)
            counts[day, default: 0] += 1
        }
        let rows = counts.keys.sorted().map { BookingsByDayRow(date: $0, count: counts[$0]!) }

        let format = try req.query.decode(FormatQuery.self).format
        if format?.lowercased() == "csv" {
            var csv = "date,count\n"
            for row in rows {
                csv += "\(row.date),\(row.count)\n"
            }
            return Self.csvResponse(csv, filename: "bookings-by-day.csv")
        }
        return try await rows.encodeResponse(for: req)
    }

    struct CapacityUtilizationRow: Content {
        var sessionID: UUID
        var title: String
        var date: String
        var capacity: Int
        var bookedCount: Int
        var utilization: Double
    }

    func capacityUtilization(req: Request) async throws -> Response {
        let sessions = try await Session.query(on: req.db).sort(\.$date).all()
        let rows = try sessions.map { session -> CapacityUtilizationRow in
            CapacityUtilizationRow(
                sessionID: try session.requireID(),
                title: session.title,
                date: Self.dayFormatter.string(from: session.date),
                capacity: session.capacity,
                bookedCount: session.bookedCount,
                utilization: ReportFormatting.utilization(bookedCount: session.bookedCount, capacity: session.capacity)
            )
        }

        let format = try req.query.decode(FormatQuery.self).format
        if format?.lowercased() == "csv" {
            var csv = "session_id,title,date,capacity,booked_count,utilization\n"
            for row in rows {
                csv += "\(row.sessionID),\(ReportFormatting.csvEscape(row.title)),\(row.date),\(row.capacity),\(row.bookedCount),\(row.utilization)\n"
            }
            return Self.csvResponse(csv, filename: "capacity-utilization.csv")
        }
        return try await rows.encodeResponse(for: req)
    }

    private static func csvResponse(_ csv: String, filename: String) -> Response {
        let response = Response(status: .ok, body: .init(string: csv))
        response.headers.contentType = HTTPMediaType(type: "text", subType: "csv")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
        return response
    }
}
