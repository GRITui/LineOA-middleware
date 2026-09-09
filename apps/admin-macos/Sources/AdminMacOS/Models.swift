import Foundation

// Mirrors apps/api/Sources/App/Models/Session.swift. Vapor's default Content
// encoder/decoder uses plain (non-snake_case) keys and ISO8601 dates, so these
// property names and the ISO8601 date decoding strategy in APIClient must match.
enum SessionStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case full

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .full: return "Full"
        }
    }
}

struct Session: Codable, Identifiable, Hashable {
    var id: UUID?
    var title: String
    var date: Date
    var startTime: String
    var endTime: String
    var capacity: Int
    var bookedCount: Int?
    var status: SessionStatus?
}

// Body for POST /sessions and PUT /sessions/:id — mirrors
// SessionController.SessionInput on the backend.
struct SessionInput: Codable {
    var title: String
    var date: Date
    var startTime: String
    var endTime: String
    var capacity: Int
    var status: SessionStatus?
}

// Mirrors SessionController.BookingWithCustomer.
enum BookingStatus: String, Codable {
    case confirmed
    case cancelled
}

struct BookingWithCustomer: Codable, Identifiable, Hashable {
    var bookingID: UUID
    var status: BookingStatus
    var createdDate: Date?
    var customerID: UUID
    var customerName: String
    var customerLineUserID: String
    var customerPhone: String?
    var customerEmail: String?

    var id: UUID { bookingID }
}
