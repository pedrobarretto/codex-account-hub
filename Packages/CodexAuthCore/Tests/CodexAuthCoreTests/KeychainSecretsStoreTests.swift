import XCTest
@testable import CodexAuthCore

final class KeychainSecretsStoreTests: XCTestCase {
    func testSaveLoadDeleteRoundTrip() throws {
        let service = "dev.codex-account-hub.tests.\(UUID().uuidString)"
        let store = KeychainSecretsStore(service: service)
        let id = UUID()
        let data = Data(#"{"auth_mode":"oauth"}"#.utf8)

        defer { try? store.deleteSecret(id: id) }

        try store.saveSecret(data, for: id)
        XCTAssertEqual(try store.loadSecret(id: id), data)

        try store.deleteSecret(id: id)
        XCTAssertThrowsError(try store.loadSecret(id: id)) { error in
            guard case .secretNotFound = error as? CodexAuthCoreError else {
                return XCTFail("Expected secretNotFound, got \(error)")
            }
        }
    }
}
