import Foundation

public enum AuthLocationSource: String, Codable, Sendable {
    case override
    case environment
    case `default`
}

public struct ResolvedAuthLocation: Equatable, Codable, Sendable {
    public let effectiveCodexHome: URL
    public let authFileURL: URL
    public let source: AuthLocationSource

    public init(effectiveCodexHome: URL, authFileURL: URL, source: AuthLocationSource) {
        self.effectiveCodexHome = effectiveCodexHome
        self.authFileURL = authFileURL
        self.source = source
    }
}

public struct ProfileMetadata: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String
    public var notes: String
    public let createdAt: Date
    public var updatedAt: Date
    public var lastImportedAt: Date?
    public var lastSwitchedAt: Date?

    public init(
        id: UUID = UUID(),
        displayName: String,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastImportedAt: Date? = nil,
        lastSwitchedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastImportedAt = lastImportedAt
        self.lastSwitchedAt = lastSwitchedAt
    }
}

public struct RunningProcess: Equatable, Codable, Hashable, Sendable {
    public let pid: Int32
    public let displayName: String
    public let command: String
    public let matchReason: String

    public init(pid: Int32, displayName: String, command: String, matchReason: String) {
        self.pid = pid
        self.displayName = displayName
        self.command = command
        self.matchReason = matchReason
    }
}

public struct SwitchPreflightResult: Equatable, Sendable {
    public let resolvedLocation: ResolvedAuthLocation
    public let blockingProcesses: [RunningProcess]
    public let warnings: [String]

    public init(
        resolvedLocation: ResolvedAuthLocation,
        blockingProcesses: [RunningProcess],
        warnings: [String]
    ) {
        self.resolvedLocation = resolvedLocation
        self.blockingProcesses = blockingProcesses
        self.warnings = warnings
    }
}

public struct SwitchResult: Equatable, Sendable {
    public let resolvedLocation: ResolvedAuthLocation
    public let backupURL: URL?
    public let switchedAt: Date

    public init(resolvedLocation: ResolvedAuthLocation, backupURL: URL?, switchedAt: Date) {
        self.resolvedLocation = resolvedLocation
        self.backupURL = backupURL
        self.switchedAt = switchedAt
    }
}

public enum LiveAuthState: Equatable, Sendable {
    case missing(ResolvedAuthLocation)
    case external(ResolvedAuthLocation)
    case active(ResolvedAuthLocation, UUID)
    case ambiguous(ResolvedAuthLocation, [UUID])
}

public enum CodexAuthCoreError: LocalizedError, Equatable {
    case invalidJSON
    case unsupportedRoot
    case secretNotFound(UUID)
    case metadataNotFound(UUID)
    case metadataCorrupt
    case readbackMismatch
    case switchBlocked([RunningProcess])
    case processExecutionFailed(String)
    case keychain(OSStatus)
    case filesystem(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The auth payload is not valid JSON."
        case .unsupportedRoot:
            return "The auth payload must be a JSON object."
        case .secretNotFound(let id):
            return "No stored auth payload was found for profile \(id.uuidString)."
        case .metadataNotFound(let id):
            return "No profile metadata was found for profile \(id.uuidString)."
        case .metadataCorrupt:
            return "The local profile metadata store is corrupt."
        case .readbackMismatch:
            return "The auth file was written, but verification failed because the readback did not match."
        case .switchBlocked(let processes):
            return "Switching is blocked because Codex-related processes are running: \(processes.map(\.displayName).joined(separator: ", "))."
        case .processExecutionFailed(let message):
            return "Unable to inspect running processes: \(message)"
        case .keychain(let status):
            return "Keychain operation failed with status \(status)."
        case .filesystem(let message):
            return "Filesystem error: \(message)"
        }
    }
}

public enum AppSupportPaths {
    public static let appDirectoryName = "CodexAccountHub"

    public static func applicationSupportDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appDirectoryName, isDirectory: true)
    }

    public static func profilesStoreURL(fileManager: FileManager = .default) -> URL {
        applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("profiles.json", isDirectory: false)
    }

    public static func backupsDirectory(fileManager: FileManager = .default) -> URL {
        applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("backups", isDirectory: true)
    }
}
