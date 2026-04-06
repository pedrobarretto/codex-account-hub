import CodexAuthCore
@testable import CodexAccountHub
import XCTest

final class ProjectSmokeTests: XCTestCase {
    func testAuthPayloadParsesWithinProjectTestTarget() throws {
        let payload = try AuthPayload(jsonString: #"{"auth_mode":"oauth","tokens":{"access_token":"abc"}}"#)
        XCTAssertEqual(payload.authMode, "oauth")
        XCTAssertTrue(payload.hasTokensObject)
    }

    func testAuthPathResolverUsesOverride() {
        let resolver = AuthPathResolver(
            environmentProvider: { ["CODEX_HOME": "/tmp/from-env"] },
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/tester", isDirectory: true) }
        )

        let resolved = resolver.resolveAuthLocation(overrideCodexHome: URL(fileURLWithPath: "/tmp/override-home", isDirectory: true))
        XCTAssertEqual(resolved.authFileURL.path, "/tmp/override-home/auth.json")
        XCTAssertEqual(resolved.source, .override)
    }

    @MainActor
    func testRenameUpdatesStoredMetadataAndActiveNameWithoutChangingPayloadMeaning() throws {
        let profile = ProfileMetadata(displayName: "Work")
        let payload = try AuthPayload(jsonString: #"{"auth_mode":"oauth","tokens":{"access_token":"abc"}}"#)
        let harness = try makeHarness(
            profiles: [(profile, payload)],
            livePayload: payload
        )
        defer { harness.cleanup() }

        harness.model.load()
        harness.model.selectProfile(id: profile.id)

        let originalPayload = try AuthPayload(data: harness.secretsStore.loadSecret(id: profile.id))

        harness.model.draft.displayName = "Personal"
        harness.model.saveDraft()

        let storedProfiles = try harness.metadataStore.loadProfiles()
        let renamedProfile = try XCTUnwrap(storedProfiles.first)
        let updatedPayload = try AuthPayload(data: harness.secretsStore.loadSecret(id: profile.id))

        XCTAssertEqual(renamedProfile.displayName, "Personal")
        XCTAssertEqual(harness.model.activeProfileName, "Personal")
        XCTAssertEqual(originalPayload, updatedPayload)
    }

    @MainActor
    func testWhitespaceOnlyRenameUsesExistingValidationAndLeavesStoredNameUnchanged() throws {
        let profile = ProfileMetadata(displayName: "Work")
        let payload = try AuthPayload(jsonString: #"{"auth_mode":"oauth","tokens":{"access_token":"abc"}}"#)
        let harness = try makeHarness(profiles: [(profile, payload)])
        defer { harness.cleanup() }

        harness.model.load()
        harness.model.selectProfile(id: profile.id)
        harness.model.draft.displayName = "   "
        harness.model.saveDraft()

        let storedProfiles = try harness.metadataStore.loadProfiles()

        XCTAssertEqual(storedProfiles.first?.displayName, "Work")
        XCTAssertEqual(harness.model.bannerMessage?.text, "Display name is required.")
    }

    @MainActor
    func testDeletingActiveStoredProfileKeepsLiveAuthFileUntouchedAndRefreshesState() throws {
        let profile = ProfileMetadata(displayName: "Work")
        let payload = try AuthPayload(jsonString: #"{"auth_mode":"oauth","tokens":{"access_token":"abc"}}"#)
        let harness = try makeHarness(
            profiles: [(profile, payload)],
            livePayload: payload
        )
        defer { harness.cleanup() }

        harness.model.load()
        let liveAuthBeforeDelete = try Data(contentsOf: harness.authFileURL)

        XCTAssertEqual(harness.model.activeProfileName, "Work")

        harness.model.selectProfile(id: profile.id)
        harness.model.requestDeleteSelectedProfile()
        harness.model.confirmDeleteSelectedProfile()

        XCTAssertTrue((try harness.metadataStore.loadProfiles()).isEmpty)
        XCTAssertEqual(try Data(contentsOf: harness.authFileURL), liveAuthBeforeDelete)
        XCTAssertNil(harness.model.activeProfileName)

        guard case .external = harness.model.liveAuthState else {
            return XCTFail("Expected the live auth file to remain external after deleting the active stored profile.")
        }
    }
}

private struct AppModelTestHarness {
    let model: AppModel
    let metadataStore: ProfileMetadataStore
    let secretsStore: InMemorySecretsStore
    let authFileURL: URL
    let rootDirectoryURL: URL
    let userDefaultsSuiteName: String

    func cleanup() {
        try? FileManager.default.removeItem(at: rootDirectoryURL)
        UserDefaults().removePersistentDomain(forName: userDefaultsSuiteName)
    }
}

private final class InMemorySecretsStore: ProfileSecretsStoring {
    private var storage: [UUID: Data] = [:]

    func loadSecret(id: UUID) throws -> Data {
        guard let data = storage[id] else {
            throw CodexAuthCoreError.secretNotFound(id)
        }
        return data
    }

    func saveSecret(_ data: Data, for id: UUID) throws {
        storage[id] = data
    }

    func deleteSecret(id: UUID) throws {
        storage.removeValue(forKey: id)
    }
}

private struct StaticProcessInspector: ProcessInspecting {
    let processes: [RunningProcess]

    func codexProcesses() throws -> [RunningProcess] {
        processes
    }
}

@MainActor
private func makeHarness(
    profiles: [(ProfileMetadata, AuthPayload)],
    livePayload: AuthPayload? = nil
) throws -> AppModelTestHarness {
    let fileManager = FileManager.default
    let rootDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let appSupportURL = rootDirectoryURL.appendingPathComponent("Application Support", isDirectory: true)
    let homeDirectoryURL = rootDirectoryURL.appendingPathComponent("Home", isDirectory: true)
    try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: homeDirectoryURL, withIntermediateDirectories: true)

    let metadataStore = ProfileMetadataStore(
        fileURL: appSupportURL.appendingPathComponent("profiles.json", isDirectory: false)
    )
    let secretsStore = InMemorySecretsStore()

    try metadataStore.saveProfiles(profiles.map(\.0))
    for (profile, payload) in profiles {
        try secretsStore.saveSecret(payload.rawData, for: profile.id)
    }

    let authPathResolver = AuthPathResolver(
        environmentProvider: { [:] },
        homeDirectoryProvider: { homeDirectoryURL }
    )
    let authFileURL = authPathResolver.resolveAuthLocation(overrideCodexHome: nil).authFileURL

    if let livePayload {
        try fileManager.createDirectory(at: authFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try livePayload.rawData.write(to: authFileURL)
    }

    let userDefaultsSuiteName = "ProjectSmokeTests.\(UUID().uuidString)"
    let userDefaults = try XCTUnwrap(UserDefaults(suiteName: userDefaultsSuiteName))
    let model = AppModel(
        metadataStore: metadataStore,
        secretsStore: secretsStore,
        authPathResolver: authPathResolver,
        processInspector: StaticProcessInspector(processes: []),
        userDefaults: userDefaults
    )

    return AppModelTestHarness(
        model: model,
        metadataStore: metadataStore,
        secretsStore: secretsStore,
        authFileURL: authFileURL,
        rootDirectoryURL: rootDirectoryURL,
        userDefaultsSuiteName: userDefaultsSuiteName
    )
}
