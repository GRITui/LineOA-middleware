import Vapor

// POST /webhooks/line — verifies the LINE Messaging API signature before
// accepting a webhook delivery. See GitHub issue #23. Event handling itself
// (postbacks, follow events, etc.) is out of scope here; this establishes the
// verification gate any future handler must sit behind.
struct LineWebhookController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.on(.POST, "webhooks", "line", body: .collect(maxSize: "1mb"), use: receive)
    }

    func receive(req: Request) async throws -> HTTPStatus {
        guard let secret = Environment.get("LINE_CHANNEL_SECRET"), !secret.isEmpty else {
            req.logger.error("LINE webhook received but LINE_CHANNEL_SECRET is not configured")
            throw Abort(.internalServerError)
        }

        guard let buffer = req.body.data else {
            throw Abort(.badRequest)
        }
        let body = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) ?? []
        let signature = req.headers.first(name: "X-Line-Signature")

        guard LineSignatureVerifier.isValid(body: body, signatureHeader: signature, channelSecret: secret) else {
            throw Abort(.unauthorized, reason: "Invalid LINE signature")
        }

        return .ok
    }
}
