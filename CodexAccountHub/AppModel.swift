import CodexAuthCore
import Foundation
import Observation
import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

struct AppTheme {
    struct BannerColors {
        let background: Color
        let symbol: Color
    }

    struct Palette {
        let isDark: Bool
        let windowGradientTop: Color
        let windowGradientBottom: Color
        let primaryCardTint: Color
        let secondaryCardTint: Color
        let cardHighlight: Color
        let cardBorder: Color
        let elevatedInsetBackground: Color
        let elevatedInsetBorder: Color
        let rowActiveBackground: Color
        let rowActiveBorder: Color
        let rowInactiveBackground: Color
        let rowInactiveBorder: Color
        let iconButtonBackground: Color
        let activeBadgeBackground: Color
        let activeBadgeForeground: Color
        let textPrimary: Color
        let textSecondary: Color
        let shadow: Color

        var windowBackground: LinearGradient {
            LinearGradient(
                colors: [windowGradientTop, windowGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func palette(for colorScheme: ColorScheme) -> Palette {
        switch colorScheme {
        case .light:
            return Palette(
                isDark: false,
                windowGradientTop: Color(red: 0.97, green: 0.98, blue: 0.995),
                windowGradientBottom: Color(red: 0.92, green: 0.95, blue: 0.985),
                primaryCardTint: Color(red: 0.21, green: 0.41, blue: 0.69),
                secondaryCardTint: Color(red: 0.43, green: 0.50, blue: 0.63),
                cardHighlight: Color.white.opacity(0.36),
                cardBorder: Color.white.opacity(0.48),
                elevatedInsetBackground: Color.white.opacity(0.54),
                elevatedInsetBorder: Color.white.opacity(0.28),
                rowActiveBackground: Color(red: 0.14, green: 0.38, blue: 0.72).opacity(0.16),
                rowActiveBorder: Color(red: 0.14, green: 0.38, blue: 0.72).opacity(0.28),
                rowInactiveBackground: Color.white.opacity(0.50),
                rowInactiveBorder: Color.white.opacity(0.30),
                iconButtonBackground: Color.white.opacity(0.70),
                activeBadgeBackground: Color(red: 0.14, green: 0.38, blue: 0.72).opacity(0.15),
                activeBadgeForeground: Color(red: 0.10, green: 0.30, blue: 0.62),
                textPrimary: Color(red: 0.14, green: 0.18, blue: 0.24),
                textSecondary: Color(red: 0.35, green: 0.41, blue: 0.49),
                shadow: Color.black.opacity(0.07)
            )
        case .dark:
            return Palette(
                isDark: true,
                windowGradientTop: Color(red: 0.07, green: 0.10, blue: 0.16),
                windowGradientBottom: Color(red: 0.11, green: 0.15, blue: 0.22),
                primaryCardTint: Color(red: 0.22, green: 0.42, blue: 0.71),
                secondaryCardTint: Color(red: 0.19, green: 0.27, blue: 0.41),
                cardHighlight: Color.white.opacity(0.08),
                cardBorder: Color.white.opacity(0.18),
                elevatedInsetBackground: Color.white.opacity(0.08),
                elevatedInsetBorder: Color.white.opacity(0.12),
                rowActiveBackground: Color(red: 0.22, green: 0.46, blue: 0.86).opacity(0.24),
                rowActiveBorder: Color(red: 0.38, green: 0.62, blue: 0.96).opacity(0.38),
                rowInactiveBackground: Color.white.opacity(0.08),
                rowInactiveBorder: Color.white.opacity(0.12),
                iconButtonBackground: Color.white.opacity(0.10),
                activeBadgeBackground: Color(red: 0.23, green: 0.47, blue: 0.88).opacity(0.26),
                activeBadgeForeground: Color(red: 0.78, green: 0.87, blue: 1.00),
                textPrimary: Color(red: 0.92, green: 0.95, blue: 0.99),
                textSecondary: Color(red: 0.63, green: 0.70, blue: 0.79),
                shadow: Color.black.opacity(0.30)
            )
        @unknown default:
            return palette(for: .light)
        }
    }

    static func bannerColors(for kind: BannerKind, in palette: Palette) -> BannerColors {
        switch kind {
        case .info:
            return BannerColors(
                background: palette.activeBadgeBackground,
                symbol: palette.activeBadgeForeground
            )
        case .success:
            return BannerColors(
                background: Color.green.opacity(palette.isDark ? 0.22 : 0.12),
                symbol: palette.isDark ? Color(red: 0.63, green: 0.92, blue: 0.72) : .green
            )
        case .warning:
            return BannerColors(
                background: Color.orange.opacity(palette.isDark ? 0.22 : 0.14),
                symbol: palette.isDark ? Color(red: 1.0, green: 0.82, blue: 0.47) : .orange
            )
        case .error:
            return BannerColors(
                background: Color.red.opacity(palette.isDark ? 0.22 : 0.14),
                symbol: palette.isDark ? Color(red: 1.0, green: 0.70, blue: 0.73) : .red
            )
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private enum DefaultsKey {
        static let codexHomeOverridePath = "codexHomeOverridePath"
        static let themeMode = "themeMode"
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
    var themeMode: ThemeMode {
        didSet {
            userDefaults.set(themeMode.rawValue, forKey: DefaultsKey.themeMode)
        }
    }

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
        self.themeMode = ThemeMode(rawValue: userDefaults.string(forKey: DefaultsKey.themeMode) ?? "") ?? .system

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

    var preferredColorScheme: ColorScheme? {
        themeMode.preferredColorScheme
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
