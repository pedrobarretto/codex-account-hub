import Foundation

public protocol ProfileMetadataStoring {
    func loadProfiles() throws -> [ProfileMetadata]
    func saveProfiles(_ profiles: [ProfileMetadata]) throws
    func markSwitched(profileID: UUID, at date: Date) throws
}

private struct ProfilesDocument: Codable {
    var version: Int
    var profiles: [ProfileMetadata]
}

public final class ProfileMetadataStore: ProfileMetadataStoring {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func loadProfiles() throws -> [ProfileMetadata] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(ProfilesDocument.self, from: data)
            return document.profiles.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch {
            throw CodexAuthCoreError.metadataCorrupt
        }
    }

    public func saveProfiles(_ profiles: [ProfileMetadata]) throws {
        let parentDirectory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let sortedProfiles = profiles.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        let data = try encoder.encode(ProfilesDocument(version: 1, profiles: sortedProfiles))
        try data.write(to: fileURL, options: .atomic)
    }

    public func markSwitched(profileID: UUID, at date: Date) throws {
        var profiles = try loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            throw CodexAuthCoreError.metadataNotFound(profileID)
        }
        profiles[index].lastSwitchedAt = date
        profiles[index].updatedAt = date
        try saveProfiles(profiles)
    }
}
