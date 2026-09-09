import Crypto
import Foundation
import XCTVapor
@testable import App

final class LineSignatureVerifierTests: XCTestCase {
    private func sign(_ body: String, secret: String) -> String {
        let key = SymmetricKey(data: Array(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Array(body.utf8), using: key)
        return Data(mac).base64EncodedString()
    }

    func testValidSignaturePasses() {
        let body = "{\"events\":[]}"
        let secret = "test-channel-secret"
        let signature = sign(body, secret: secret)

        XCTAssertTrue(LineSignatureVerifier.isValid(body: Array(body.utf8), signatureHeader: signature, channelSecret: secret))
    }

    func testWrongSecretFails() {
        let body = "{\"events\":[]}"
        let signature = sign(body, secret: "test-channel-secret")

        XCTAssertFalse(LineSignatureVerifier.isValid(body: Array(body.utf8), signatureHeader: signature, channelSecret: "wrong-secret"))
    }

    func testTamperedBodyFails() {
        let secret = "test-channel-secret"
        let signature = sign("{\"events\":[]}", secret: secret)

        XCTAssertFalse(LineSignatureVerifier.isValid(body: Array("{\"events\":[1]}".utf8), signatureHeader: signature, channelSecret: secret))
    }

    func testMissingSignatureFails() {
        XCTAssertFalse(LineSignatureVerifier.isValid(body: Array("{}".utf8), signatureHeader: nil, channelSecret: "test-channel-secret"))
    }

    func testMalformedSignatureFails() {
        XCTAssertFalse(LineSignatureVerifier.isValid(body: Array("{}".utf8), signatureHeader: "not-base64!!", channelSecret: "test-channel-secret"))
    }
}
