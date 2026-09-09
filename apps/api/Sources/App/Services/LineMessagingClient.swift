import Vapor

// See GitHub issue #15.
protocol LineMessagingClient: Sendable {
    func pushMessage(to userID: String, text: String) async throws

    // See GitHub issue #14: reply to an inbound message with a buttons
    // template CTA that opens the Mini App (Book Now / View Available Slots).
    func replyBookingCTA(replyToken: String, liffURL: String) async throws
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

    private struct ReplyMessageRequest: Content {
        let replyToken: String
        let messages: [TemplateMessage]
    }

    private struct TemplateMessage: Content {
        let type: String
        let altText: String
        let template: ButtonsTemplate

        init(altText: String, template: ButtonsTemplate) {
            self.type = "template"
            self.altText = altText
            self.template = template
        }
    }

    private struct ButtonsTemplate: Content {
        let type: String
        let text: String
        let actions: [URIAction]

        init(text: String, actions: [URIAction]) {
            self.type = "buttons"
            self.text = text
            self.actions = actions
        }
    }

    private struct URIAction: Content {
        let type: String
        let label: String
        let uri: String

        init(label: String, uri: String) {
            self.type = "uri"
            self.label = label
            self.uri = uri
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

    func replyBookingCTA(replyToken: String, liffURL: String) async throws {
        let uri = URI(string: "https://api.line.me/v2/bot/message/reply")
        let template = TemplateMessage(
            altText: "Book a session or view available slots",
            template: ButtonsTemplate(
                text: "Ready to book?",
                actions: [
                    URIAction(label: "Book Now", uri: liffURL),
                    URIAction(label: "View Available Slots", uri: liffURL),
                ]
            )
        )
        let response = try await client.post(uri) { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: channelAccessToken)
            req.headers.contentType = .json
            try req.content.encode(ReplyMessageRequest(replyToken: replyToken, messages: [template]))
        }
        guard (200..<300).contains(response.status.code) else {
            throw Abort(.badGateway, reason: "LINE reply failed with status \(response.status.code)")
        }
    }
}

// No-op fallback so the app runs (e.g. in tests, or with no channel token configured) without
// a live LINE dependency.
struct NoopLineMessagingClient: LineMessagingClient {
    func pushMessage(to userID: String, text: String) async throws {}
    func replyBookingCTA(replyToken: String, liffURL: String) async throws {}
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
