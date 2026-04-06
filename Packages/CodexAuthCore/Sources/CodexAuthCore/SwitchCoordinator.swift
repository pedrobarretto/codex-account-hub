import Foundation

public final class SwitchCoordinator {
    private let authPathResolver: AuthPathResolving
    private let secretsStore: ProfileSecretsStoring
    private let metadataStore: ProfileMetadataStoring
    private let processInspector: ProcessInspecting
    private let fileManager: FileManager
    private let backupsDirectoryProvider: () -> URL
    private let clock: () -> Date

    public init(
        authPathResolver: AuthPathResolving,
        secretsStore: ProfileSecretsStoring,
        metadataStore: ProfileMetadataStoring,
        processInspector: ProcessInspecting,
        fileManager: FileManager = .default,
        backupsDirectoryProvider: @escaping () -> URL,
        clock: @escaping () -> Date = Date.init
    ) {
        self.authPathResolver = authPathResolver
        self.secretsStore = secretsStore
        self.metadataStore = metadataStore
        self.processInspector = processInspector
        self.fileManager = fileManager
        self.backupsDirectoryProvider = backupsDirectoryProvider
        self.clock = clock
    }

    public func preflightSwitch(profileID: UUID, overrideCodexHome: URL? = nil) throws -> SwitchPreflightResult {
        _ = try AuthPayload(data: try secretsStore.loadSecret(id: profileID))
        let processes = try processInspector.codexProcesses()
        let resolvedLocation = authPathResolver.resolveAuthLocation(overrideCodexHome: overrideCodexHome)
        let warnings = processes.isEmpty
            ? []
            : ["Already-running Codex processes may keep using old credentials until restarted."]
        return SwitchPreflightResult(
            resolvedLocation: resolvedLocation,
            blockingProcesses: processes,
            warnings: warnings
        )
    }

    @discardableResult
    public func switchToProfile(
        profileID: UUID,
        overrideCodexHome: URL? = nil,
        allowUnsafe: Bool = false
    ) throws -> SwitchResult {
        let preflight = try preflightSwitch(profileID: profileID, overrideCodexHome: overrideCodexHome)
        if !allowUnsafe, !preflight.blockingProcesses.isEmpty {
            throw CodexAuthCoreError.switchBlocked(preflight.blockingProcesses)
        }

        let authData = try secretsStore.loadSecret(id: profileID)
        let payload = try AuthPayload(data: authData)
        let authURL = preflight.resolvedLocation.authFileURL
        let parentDirectory = authURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        let backupURL = try backupCurrentAuthIfNeeded(at: authURL)
        try writeAtomically(payload.rawData, to: authURL)
        let reloaded = try AuthPayload(data: Data(contentsOf: authURL))
        guard reloaded == payload else {
            throw CodexAuthCoreError.readbackMismatch
        }

        let switchedAt = clock()
        try metadataStore.markSwitched(profileID: profileID, at: switchedAt)
        return SwitchResult(resolvedLocation: preflight.resolvedLocation, backupURL: backupURL, switchedAt: switchedAt)
    }

    public func resolveLiveAuthState(
        profiles: [ProfileMetadata],
        overrideCodexHome: URL? = nil
    ) throws -> LiveAuthState {
        let resolvedLocation = authPathResolver.resolveAuthLocation(overrideCodexHome: overrideCodexHome)
        guard fileManager.fileExists(atPath: resolvedLocation.authFileURL.path) else {
            return .missing(resolvedLocation)
        }

        let currentPayload = try AuthPayload(data: Data(contentsOf: resolvedLocation.authFileURL))
        let matchingIDs = profiles.compactMap { profile -> UUID? in
            guard let storedPayload = try? AuthPayload(data: secretsStore.loadSecret(id: profile.id)) else {
                return nil
            }
            return storedPayload == currentPayload ? profile.id : nil
        }

        switch matchingIDs.count {
        case 0:
            return .external(resolvedLocation)
        case 1:
            return .active(resolvedLocation, matchingIDs[0])
        default:
            return .ambiguous(resolvedLocation, matchingIDs)
        }
    }

    private func backupCurrentAuthIfNeeded(at authURL: URL) throws -> URL? {
        guard fileManager.fileExists(atPath: authURL.path) else {
            return nil
        }

        let backupsDirectory = backupsDirectoryProvider()
        try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupURL = backupsDirectory.appendingPathComponent("auth-\(formatter.string(from: clock())).json")
        do {
            try fileManager.copyItem(at: authURL, to: backupURL)
        } catch {
            throw CodexAuthCoreError.filesystem("Unable to create backup at \(backupURL.path): \(error.localizedDescription)")
        }
        return backupURL
    }

    private func writeAtomically(_ data: Data, to authURL: URL) throws {
        let directory = authURL.deletingLastPathComponent()
        let tempURL = directory.appendingPathComponent(".auth-\(UUID().uuidString).tmp")

        do {
            try data.write(to: tempURL, options: .withoutOverwriting)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)

            if fileManager.fileExists(atPath: authURL.path) {
                _ = try fileManager.replaceItemAt(authURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: authURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw CodexAuthCoreError.filesystem("Unable to write auth file at \(authURL.path): \(error.localizedDescription)")
        }
    }
}
