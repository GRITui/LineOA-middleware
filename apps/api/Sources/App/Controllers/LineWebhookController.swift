import Vapor

// POST /webhooks/line — verifies the LINE Messaging API signature before
// accepting a webhook delivery. See GitHub issue #23. Beyond signature
// verification, the only event handling implemented is the booking-intent
// CTA reply (see GitHub issue #14, on top of the same gate).
struct LineWebhookController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.on(.POST, "webhooks", "line", body: .collect(maxSize: "1mb"), use: receive)
    }

    struct WebhookPayload: Content {
        var events: [WebhookEvent]
    }

    struct WebhookEvent: Content {
        var type: String
        var replyToken: String?
        var message: WebhookMessage?
    }

    struct WebhookMessage: Content {
        var type: String
        var text: String?
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

        await handleBookingIntents(req: req)

        return .ok
    }

    // Best-effort: a malformed payload or a reply failure shouldn't turn a verified
    // webhook delivery into an error response (LINE would retry the whole delivery).
    private func handleBookingIntents(req: Request) async {
        guard let liffURL = Self.liffURL(req: req) else {
            req.logger.warning("Booking-intent CTA skipped: no LIFF URL configured (set LIFF_URL or LINE_LIFF_ID)")
            return
        }

        let payload: WebhookPayload
        do {
            payload = try req.content.decode(WebhookPayload.self)
        } catch {
            req.logger.debug("LINE webhook payload had no decodable events: \(error)")
            return
        }

        for event in payload.events {
            guard event.type == "message",
                  event.message?.type == "text",
                  let text = event.message?.text,
                  let replyToken = event.replyToken,
                  BookingIntentMatcher.isBookingIntent(text)
            else { continue }

            do {
                try await req.application.lineMessaging.replyBookingCTA(replyToken: replyToken, liffURL: liffURL)
            } catch {
                req.logger.error("Booking-intent CTA reply failed: \(error)")
            }
        }
    }

    static func liffURL(req: Request) -> String? {
        if let explicit = Environment.get("LIFF_URL"), !explicit.isEmpty {
            return explicit
        }
        if let liffID = Environment.get("LINE_LIFF_ID"), !liffID.isEmpty {
            return "https://liff.line.me/\(liffID)"
        }
        return nil
    }
}
