import Crypto
import Foundation

// Verifies the `X-Line-Signature` header LINE sends on every webhook request:
// base64(HMAC-SHA256(channelSecret, rawBody)). See GitHub issue #23.
// https://developers.line.biz/en/reference/messaging-api/#signature-validation
enum LineSignatureVerifier {
    static func isValid(body: [UInt8], signatureHeader: String?, channelSecret: String) -> Bool {
        guard let signatureHeader, let expected = Data(base64Encoded: signatureHeader) else { return false }
        let key = SymmetricKey(data: Array(channelSecret.utf8))
        // Constant-time comparison, courtesy of swift-crypto.
        return HMAC<SHA256>.isValidAuthenticationCode(expected, authenticating: body, using: key)
    }
}
