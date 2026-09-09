import Foundation

// Prototype config: no auth, single hardcoded/overridable base URL.
// See GitHub issue #28 — this app is a thin admin client over apps/api.
enum APIConfig {
    /// Override at launch with `LINEOA_API_BASE_URL=https://example.com`, e.g. for
    /// pointing at a staging/deployed backend instead of localhost during development.
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["LINEOA_API_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "http://localhost:8080")!
    }
}
