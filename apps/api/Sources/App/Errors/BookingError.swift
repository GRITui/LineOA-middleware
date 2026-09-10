import Vapor

enum BookingError: AbortError {
    case duplicate

    var status: HTTPResponseStatus {
        switch self {
        case .duplicate: return .conflict
        }
    }

    var reason: String {
        switch self {
        case .duplicate:
            return "Booking already exists for this customer and session"
        }
    }
}