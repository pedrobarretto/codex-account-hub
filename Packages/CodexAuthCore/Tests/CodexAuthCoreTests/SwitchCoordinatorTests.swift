import XCTest
@testable import CodexAuthCore

private final class InMemorySecretsStore: ProfileSecretsStoring {
    var values: [UUID: Data] = [:]

    func loadSecret(id: UUID) throws -> Data {
        guard let data = values[id] else {
            throw CodexAuthCoreError.secretNotFound(id)
        }
        return data
    }

    func saveSecret(_ data: Data, for id: UUID) throws {
        values[id] = data
    }

    func deleteSecret(id: UUID) throws {
        values.removeValue(forKey: id)
    }
}

private final class InMemoryMetadataStore: ProfileMetadataStoring {
    var profiles: [ProfileMetadata] = []

    func loadProfiles() throws -> [ProfileMetadata] { profiles }
    func saveProfiles(_ profiles: [ProfileMetadata]) throws { self.profiles = profiles }

    func markSwitched(profileID: UUID, at date: Date) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            throw CodexAuthCoreError.metadataNotFound(profileID)
        }
        profiles[index].lastSwitchedAt = date
        profiles[index].updatedAt = date
    }
}

private struct StubResolver: AuthPathResolving {
    let location: ResolvedAuthLocation
    func resolveAuthLocation(overrideCodexHome: URL?) -> ResolvedAuthLocation { location }
}

private struct StubInspector: ProcessInspecting {
    let processes: [RunningProcess]
    func codexProcesses() throws -> [RunningProcess] { processes }
}

final class SwitchCoordinatorTests: XCTestCase {
    func testBlocksWhenProcessesAreRunning() throws {
        let id = UUID()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let location = ResolvedAuthLocation(
            effectiveCodexHome: tempDirectory,
            authFileURL: tempDirectory.appendingPathComponent("auth.json"),
            source: .default
        )
        let secrets = InMemorySecretsStore()
        try secrets.saveSecret(Data(#"{"auth_mode":"oauth"}"#.utf8), for: id)
        let metadata = InMemoryMetadataStore()
        metadata.profiles = [ProfileMetadata(id: id, displayName: "Work")]
        let coordinator = SwitchCoordinator(
            authPathResolver: StubResolver(location: location),
            secretsStore: secrets,
            metadataStore: metadata,
            processInspector: StubInspector(processes: [
                RunningProcess(pid: 1, displayName: "Codex", command: "Codex", matchReason: "Running Codex desktop application")
            ]),
            backupsDirectoryProvider: { tempDirectory.appendingPathComponent("backups", isDirectory: true) },
            clock: { Date(timeIntervalSince1970: 100) }
        )

        XCTAssertThrowsError(try coordinator.switchToProfile(profileID: id)) { error in
            guard case .switchBlocked(let processes) = error as? CodexAuthCoreError else {
                return XCTFail("Expected switchBlocked, got \(error)")
            }
            XCTAssertEqual(processes.count, 1)
        }
    }

    func testWritesBackupAndMarksSwitch() throws {
        let id = UUID()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let authURL = tempDirectory.appendingPathComponent("auth.json")
        try Data(#"{"auth_mode":"old"}"#.utf8).write(to: authURL)

        let location = ResolvedAuthLocation(
            effectiveCodexHome: tempDirectory,
            authFileURL: authURL,
            source: .default
        )
        let secrets = InMemorySecretsStore()
        try secrets.saveSecret(Data(#"{"auth_mode":"new","tokens":{"access_token":"123"}}"#.utf8), for: id)
        let metadata = InMemoryMetadataStore()
        metadata.profiles = [ProfileMetadata(id: id, displayName: "Personal")]

        let coordinator = SwitchCoordinator(
            authPathResolver: StubResolver(location: location),
            secretsStore: secrets,
            metadataStore: metadata,
            processInspector: StubInspector(processes: []),
            backupsDirectoryProvider: { tempDirectory.appendingPathComponent("backups", isDirectory: true) },
            clock: { Date(timeIntervalSince1970: 1_234) }
        )

        let result = try coordinator.switchToProfile(profileID: id)
        XCTAssertNotNil(result.backupURL)
        XCTAssertEqual(try AuthPayload(data: Data(contentsOf: authURL)).authMode, "new")
        XCTAssertEqual(metadata.profiles.first?.lastSwitchedAt, Date(timeIntervalSince1970: 1_234))
    }

    func testResolveLiveAuthState() throws {
        let firstID = UUID()
        let secondID = UUID()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let authURL = tempDirectory.appendingPathComponent("auth.json")
        try Data(#"{"auth_mode":"match"}"#.utf8).write(to: authURL)

        let location = ResolvedAuthLocation(
            effectiveCodexHome: tempDirectory,
            authFileURL: authURL,
            source: .default
        )
        let secrets = InMemorySecretsStore()
        try secrets.saveSecret(Data(#"{"auth_mode":"match"}"#.utf8), for: firstID)
        try secrets.saveSecret(Data(#"{"auth_mode":"other"}"#.utf8), for: secondID)
        let metadata = InMemoryMetadataStore()
        metadata.profiles = [
            ProfileMetadata(id: firstID, displayName: "Matching"),
            ProfileMetadata(id: secondID, displayName: "Other")
        ]
        let coordinator = SwitchCoordinator(
            authPathResolver: StubResolver(location: location),
            secretsStore: secrets,
            metadataStore: metadata,
            processInspector: StubInspector(processes: []),
            backupsDirectoryProvider: { tempDirectory.appendingPathComponent("backups", isDirectory: true) }
        )

        let state = try coordinator.resolveLiveAuthState(profiles: metadata.profiles)
        XCTAssertEqual(state, .active(location, firstID))
    }
}
