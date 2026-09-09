import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .http(let status, let body):
            return "Request failed (\(status)): \(body.isEmpty ? "no details" : body)"
        }
    }
}

// Thin URLSession wrapper over apps/api's admin session/booking endpoints.
// No auth — prototype-scoped per GitHub issue #28.
final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(baseURL: URL = APIConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: Sessions

    func listSessions() async throws -> [Session] {
        try await request("sessions", method: "GET")
    }

    func createSession(_ input: SessionInput) async throws -> Session {
        try await request("sessions", method: "POST", body: input)
    }

    func updateSession(id: UUID, _ input: SessionInput) async throws -> Session {
        try await request("sessions/\(id.uuidString)", method: "PUT", body: input)
    }

    func bookings(forSession id: UUID) async throws -> [BookingWithCustomer] {
        try await request("sessions/\(id.uuidString)/bookings", method: "GET")
    }

    // MARK: Core request helper

    private func request<Response: Decodable>(
        _ path: String,
        method: String
    ) async throws -> Response {
        try await request(path, method: method, body: Optional<String>.none)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.http(status: httpResponse.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try decoder.decode(Response.self, from: data)
    }
}
