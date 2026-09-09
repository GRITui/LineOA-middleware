import Foundation

// See GitHub issue #14: keyword match for "the user probably wants to book"
// on an inbound LINE text message. Deliberately simple/pragmatic for a
// prototype — a false positive just shows the CTA again, which is harmless.
enum BookingIntentMatcher {
    private static let keywords = [
        "book", "booking", "reserve", "reservation", "slot", "available", "availability",
        "จอง", "จองคิว", "ว่าง",
    ]

    static func isBookingIntent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return keywords.contains { lowered.contains($0) }
    }
}
