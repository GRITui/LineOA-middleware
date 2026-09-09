import XCTVapor
@testable import App

final class AppTests: XCTestCase {
    func testHealthEndpoint() async throws {
        let app = try await Application.make(.testing)
        do {
            try configure(app)
            try await app.test(.GET, "health") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "ok")
            }
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}
