import CodexAuthCore
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private enum DefaultsKey {
        static let codexHomeOverridePath = "codexHomeOverridePath"
    }

    private let metadataStore: ProfileMetadataStoring
    private let secretsStore: ProfileSecretsStoring
    private let authPathResolver: AuthPathResolving
    private let processInspector: ProcessInspecting
    private let switchCoordinator: SwitchCoordinator
    private let userDefaults: UserDefaults
    private let clock: () -> Date

    var profiles: [ProfileMetadata] = []
    var selectedProfileID: UUID?
    var draft: ProfileDraft = .empty
    var resolvedLocation: ResolvedAuthLocation
    var liveAuthState: LiveAuthState
    var runningProcesses: [RunningProcess] = []
    var bannerMessage: BannerMessage?
    var pendingDeleteProfile: ProfileMetadata?
    var pendingForceSwitchProfileID: UUID?
    var pendingForceSwitchProcesses: [RunningProcess] = []
    var codexHomeOverridePath: String

    init(
        metadataStore: ProfileMetadataStoring? = nil,
        secretsStore: ProfileSecretsStoring? = nil,
        authPathResolver: AuthPathResolving? = nil,
        processInspector: ProcessInspecting? = nil,
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = Date.init
    ) {
        let resolvedMetadataStore = metadataStore ?? ProfileMetadataStore(fileURL: AppSupportPaths.profilesStoreURL())
        let resolvedSecretsStore = secretsStore ?? KeychainSecretsStore()
        let resolvedAuthPathResolver = authPathResolver ?? AuthPathResolver()
        let resolvedProcessInspector = processInspector ?? ProcessInspector()

        self.metadataStore = resolvedMetadataStore
        self.secretsStore = resolvedSecretsStore
        self.authPathResolver = resolvedAuthPathResolver
        self.processInspector = resolvedProcessInspector
        self.userDefaults = userDefaults
        self.clock = clock
        self.codexHomeOverridePath = userDefaults.string(forKey: DefaultsKey.codexHomeOverridePath) ?? ""

        let initialLocation = resolvedAuthPathResolver.resolveAuthLocation(overrideCodexHome: Self.overrideURL(from: userDefaults.string(forKey: DefaultsKey.codexHomeOverridePath) ?? ""))
        self.resolvedLocation = initialLocation
        self.liveAuthState = .missing(initialLocation)
        self.switchCoordinator = SwitchCoordinator(
            authPathResolver: resolvedAuthPathResolver,
            secretsStore: resolvedSecretsStore,
            metadataStore: resolvedMetadataStore,
            processInspector: resolvedProcessInspector,
            backupsDirectoryProvider: { AppSupportPaths.backupsDirectory() },
            clock: clock
        )
    }

    var selectedProfile: ProfileMetadata? {
        guard let selectedProfileID else { return nil }
        return profiles.first(where: { $0.id == selectedProfileID })
    }

    var sortedProfiles: [ProfileMetadata] {
        profiles.sorted { lhs, rhs in
            let lhsActive = isActive(lhs)
            let rhsActive = isActive(rhs)
            if lhsActive != rhsActive {
                return lhsActive && !rhsActive
            }

            let lhsRecent = lhs.lastSwitchedAt ?? lhs.lastImportedAt ?? lhs.updatedAt
            let rhsRecent = rhs.lastSwitchedAt ?? rhs.lastImportedAt ?? rhs.updatedAt
            if lhsRecent != rhsRecent {
                return lhsRecent > rhsRecent
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var activeProfileName: String? {
        guard let activeProfileID else { return nil }
        return profiles.first(where: { $0.id == activeProfileID })?.displayName
    }

    var currentOverrideURL: URL? {
        Self.overrideURL(from: codexHomeOverridePath)
    }

    var draftValidation: DraftValidation {
        guard !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("Display name is required.")
        }

        do {
            return .valid(try AuthPayload(jsonString: draft.authJSONString))
        } catch {
            return .invalid(error.localizedDescription)
        }
    }

    var activeStateDescription: String {
        switch liveAuthState {
        case .missing:
            return "No live auth file is present at the effective location."
        case .external:
            return "A live auth file exists, but it does not match any stored profile."
        case .active(_, let id):
            let name = profiles.first(where: { $0.id == id })?.displayName ?? "Stored profile"
            return "\(name) matches the live auth file."
        case .ambiguous(_, let ids):
            return "The live auth file matches \(ids.count) stored profiles."
        }
    }

    var processStateDescription: String {
        if runningProcesses.isEmpty {
            return "No Codex-related processes detected."
        }
        return "\(runningProcesses.count) Codex-related process(es) detected. Switching is blocked until they stop or you explicitly force-switch."
    }

    func load() {
        refreshAll(preserveSelection: selectedProfileID)
    }

    func refreshAll(preserveSelection: UUID?) {
        do {
            profiles = try metadataStore.loadProfiles()
            resolvedLocation = authPathResolver.resolveAuthLocation(overrideCodexHome: currentOverrideURL)
            liveAuthState = try switchCoordinator.resolveLiveAuthState(profiles: profiles, overrideCodexHome: currentOverrideURL)
            runningProcesses = try processInspector.codexProcesses()

            let nextSelection = preserveSelection.flatMap { preserved in
                profiles.first(where: { $0.id == preserved })?.id
            } ?? activeProfileID ?? profiles.first?.id

            selectProfile(id: nextSelection)
        } catch {
            bannerMessage = BannerMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func selectProfile(id: UUID?) {
        selectedProfileID = id
        guard let id, let profile = profiles.first(where: { $0.id == id }) else {
            draft = .empty
            return
        }

        do {
            let payload = try AuthPayload(data: secretsStore.loadSecret(id: id))
            draft = ProfileDraft(
                id: profile.id,
                displayName: profile.displayName,
                notes: profile.notes,
                authJSONString: try payload.prettyPrintedString()
            )
        } catch {
            bannerMessage = BannerMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func startNewProfile() {
        selectedProfileID = nil
        draft = .empty
    }

    func duplicateSelectedProfile() {
        draft = ProfileDraft(
            id: nil,
            displayName: draft.displayName.isEmpty ? "Imported Copy" : "\(draft.displayName) Copy",
            notes: draft.notes,
            authJSONString: draft.authJSONString
        )
        selectedProfileID = nil
        bannerMessage = BannerMessage(kind: .info, text: "Created a duplicate draft. Save it to store a new profile.")
    }

    func saveDraft(lastImportedAt: Date? = nil) {
        switch draftValidation {
        case .invalid(let message):
            bannerMessage = BannerMessage(kind: .error, text: message)
        case .valid(let payload):
            do {
                var allProfiles = try metadataStore.loadProfiles()
                let now = clock()

                if let existingID = draft.id, let index = allProfiles.firstIndex(where: { $0.id == existingID }) {
                    allProfiles[index].displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    allProfiles[index].notes = draft.notes
                    allProfiles[index].updatedAt = now
                    if let lastImportedAt {
                        allProfiles[index].lastImportedAt = lastImportedAt
                    }
                    try secretsStore.saveSecret(payload.rawData, for: existingID)
                    try metadataStore.saveProfiles(allProfiles)
                    bannerMessage = BannerMessage(kind: .success, text: "Updated \(allProfiles[index].displayName).")
                    refreshAll(preserveSelection: existingID)
                } else {
                    let newProfile = ProfileMetadata(
                        displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: draft.notes,
                        createdAt: now,
                        updatedAt: now,
                        lastImportedAt: lastImportedAt
                    )
                    try secretsStore.saveSecret(payload.rawData, for: newProfile.id)
                    allProfiles.append(newProfile)
                    try metadataStore.saveProfiles(allProfiles)
                    bannerMessage = BannerMessage(kind: .success, text: "Saved \(newProfile.displayName).")
                    refreshAll(preserveSelection: newProfile.id)
                }
            } catch {
                bannerMessage = BannerMessage(kind: .error, text: error.localizedDescription)
            }
        }
    }

    func importProfile(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let payload = try AuthPayload(data: data)
            draft = ProfileDraft(
                id: nil,
                displayName: url.deletingPathExtension().lastPathComponent,
                notes: "Imported from \(url.path)",
                authJSONString: try payload.prettyPrintedString()
            )
            saveDraft(lastImportedAt: clock())
        } catch {
            bannerMessage = BannerMessage(kind: .error, text: "Import failed: \(error.localizedDescription)")
        }
    }

    func importCurrentEffectiveAuth() {
        guard FileManager.default.fileExists(atPath: resolvedLocation.authFileURL.path) else {
            bannerMessage = BannerMessage(kind: .error, text: "No auth file exists at \(resolvedLocation.authFileURL.path).")
            return
        }
        importProfile(from: resolvedLocation.authFileURL)
    }

    func requestDeleteSelectedProfile() {
        pendingDeleteProfile = selectedProfile
    }

    func confirmDeleteSelectedProfile() {
        guard let profile = pendingDeleteProfile else { return }
        do {
            try secretsStore.deleteSecret(id: profile.id)
            var allProfiles = try metadataStore.loadProfiles()
            allProfiles.removeAll(where: { $0.id == profile.id })
            try metadataStore.saveProfiles(allProfiles)
            pendingDeleteProfile = nil
            bannerMessage = BannerMessage(kind: .warning, text: "Deleted \(profile.displayName).")
            refreshAll(preserveSelection: nil)
        } catch {
            bannerMessage = BannerMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func attemptSwitchSelectedProfile() {
        guard let selectedProfileID else {
            bannerMessage = BannerMessage(kind: .error, text: "Select a saved profile before switching.")
            return
        }

        attemptSwitch(profileID: selectedProfileID)
    }

    func attemptSwitch(profileID: UUID) {
        guard profiles.contains(where: { $0.id == profileID }) else {
            bannerMessage = BannerMessage(kind: .error, text: "The selected profile no longer exists.")
            return
        }

        do {
            let preflight = try preflightSwitch(profileID: profileID)
            if preflight.blockingProcesses.isEmpty {
                try switchProfileImmediately(profileID: profileID, allowUnsafe: false)
            } else {
                pendingForceSwitchProfileID = profileID
                pendingForceSwitchProcesses = preflight.blockingProcesses
                bannerMessage = BannerMessage(kind: .warning, text: "Switching is blocked until Codex processes stop or you force-switch.")
            }
        } catch {
            bannerMessage = BannerMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func preflightSwitch(profileID: UUID) throws -> SwitchPreflightResult {
        try switchCoordinator.preflightSwitch(profileID: profileID, overrideCodexHome: currentOverrideURL)
    }

    func confirmForceSwitch() {
        guard let profileID = pendingForceSwitchProfileID else { return }
        do {
            try switchProfileImmediately(profileID: profileID, allowUnsafe: true)
            pendingForceSwitchProfileID = nil
            pendingForceSwitchProcesses = []
        } catch {
            bannerMessage = BannerMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func clearForceSwitchPrompt() {
        pendingForceSwitchProfileID = nil
        pendingForceSwitchProcesses = []
    }

    func applyCodexHomeOverride() {
        userDefaults.set(codexHomeOverridePath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKey.codexHomeOverridePath)
        bannerMessage = BannerMessage(kind: .info, text: "Updated the explicit Codex home override.")
        refreshAll(preserveSelection: selectedProfileID)
    }

    func clearCodexHomeOverride() {
        codexHomeOverridePath = ""
        userDefaults.removeObject(forKey: DefaultsKey.codexHomeOverridePath)
        bannerMessage = BannerMessage(kind: .info, text: "Cleared the explicit Codex home override.")
        refreshAll(preserveSelection: selectedProfileID)
    }

    func dismissBanner() {
        bannerMessage = nil
    }

    func isActive(_ profile: ProfileMetadata) -> Bool {
        if case .active(_, let activeID) = liveAuthState {
            return activeID == profile.id
        }
        return false
    }

    private var activeProfileID: UUID? {
        if case .active(_, let activeID) = liveAuthState {
            return activeID
        }
        return nil
    }

    func switchProfileImmediately(profileID: UUID, allowUnsafe: Bool) throws {
        let result = try switchCoordinator.switchToProfile(
            profileID: profileID,
            overrideCodexHome: currentOverrideURL,
            allowUnsafe: allowUnsafe
        )

        let profileName = profiles.first(where: { $0.id == profileID })?.displayName ?? "Selected profile"
        if let backupURL = result.backupURL {
            bannerMessage = BannerMessage(
                kind: .success,
                text: "Switched to \(profileName). Previous auth backed up to \(backupURL.lastPathComponent). Restart running Codex processes if needed."
            )
        } else {
            bannerMessage = BannerMessage(
                kind: .success,
                text: "Switched to \(profileName). Restart running Codex processes if needed."
            )
        }
        refreshAll(preserveSelection: profileID)
    }

    private static func overrideURL(from rawPath: String) -> URL? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
}
