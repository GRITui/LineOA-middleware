import Vapor

// See GitHub issue #15.
protocol LineMessagingClient: Sendable {
    func pushMessage(to userID: String, text: String) async throws
}

struct LiveLineMessagingClient: LineMessagingClient {
    let client: Client
    let channelAccessToken: String

    private struct PushMessageRequest: Content {
        let to: String
        let messages: [TextMessage]
    }

    private struct TextMessage: Content {
        let type: String
        let text: String

        init(text: String) {
            self.type = "text"
            self.text = text
        }
    }

    func pushMessage(to userID: String, text: String) async throws {
        let uri = URI(string: "https://api.line.me/v2/bot/message/push")
        let response = try await client.post(uri) { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: channelAccessToken)
            req.headers.contentType = .json
            try req.content.encode(PushMessageRequest(to: userID, messages: [TextMessage(text: text)]))
        }
        guard (200..<300).contains(response.status.code) else {
            throw Abort(.badGateway, reason: "LINE push failed with status \(response.status.code)")
        }
    }
}

// No-op fallback so the app runs (e.g. in tests, or with no channel token configured) without
// a live LINE dependency.
struct NoopLineMessagingClient: LineMessagingClient {
    func pushMessage(to userID: String, text: String) async throws {}
}

private struct LineMessagingClientKey: StorageKey {
    typealias Value = LineMessagingClient
}

extension Application {
    var lineMessaging: LineMessagingClient {
        get { storage[LineMessagingClientKey.self] ?? NoopLineMessagingClient() }
        set { storage[LineMessagingClientKey.self] = newValue }
    }
}
