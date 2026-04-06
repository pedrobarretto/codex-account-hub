import XCTest
@testable import CodexAuthCore

final class ProfileMetadataStoreTests: XCTestCase {
    func testRoundTripsProfiles() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProfileMetadataStore(fileURL: tempDirectory.appendingPathComponent("profiles.json"))

        let original = [
            ProfileMetadata(displayName: "Work", notes: "primary"),
            ProfileMetadata(displayName: "Personal", notes: "secondary")
        ]
        try store.saveProfiles(original)

        let loaded = try store.loadProfiles()
        XCTAssertEqual(Set(loaded.map(\.displayName)), Set(["Work", "Personal"]))
    }

    func testMissingStoreReturnsEmpty() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProfileMetadataStore(fileURL: tempDirectory.appendingPathComponent("profiles.json"))
        XCTAssertEqual(try store.loadProfiles(), [])
    }

    func testCorruptStoreThrows() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("profiles.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = ProfileMetadataStore(fileURL: fileURL)

        XCTAssertThrowsError(try store.loadProfiles()) { error in
            XCTAssertEqual(error as? CodexAuthCoreError, .metadataCorrupt)
        }
    }
}
