import XCTest
@testable import CodexAuthCore

final class AuthPayloadTests: XCTestCase {
    func testAcceptsJSONObject() throws {
        let payload = try AuthPayload(jsonString: #"{"tokens":{"access_token":"abc"},"auth_mode":"oauth"}"#)
        XCTAssertEqual(payload.authMode, "oauth")
        XCTAssertTrue(payload.hasTokensObject)
    }

    func testRejectsArrayRoot() {
        XCTAssertThrowsError(try AuthPayload(jsonString: #"[1,2,3]"#)) { error in
            XCTAssertEqual(error as? CodexAuthCoreError, .unsupportedRoot)
        }
    }

    func testCanonicalizesDeterministically() throws {
        let first = try AuthPayload(jsonString: #"{"b":2,"a":1}"#)
        let second = try AuthPayload(jsonString: #"{"a":1,"b":2}"#)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.canonicalData, second.canonicalData)
    }
}
