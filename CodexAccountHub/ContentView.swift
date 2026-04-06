import AppKit
import CodexAuthCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel
    @Bindable var runtime: AppRuntime
    @Environment(\.colorScheme) private var colorScheme
    @State private var editedProfileID: UUID?
    @State private var isShowingRenameSheet = false
    @State private var renameDisplayName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                actionsCard

                if let banner = model.bannerMessage {
                    BannerMessageCard(banner: banner) {
                        model.dismissBanner()
                    }
                }

                if let banner = runtime.bannerMessage {
                    BannerMessageCard(banner: banner) {
                        runtime.dismissBanner()
                    }
                }

                profilesCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 460, height: 620)
        .background(windowBackground)
        .alert(
            "Force Switch While Codex Is Running?",
            isPresented: Binding(
                get: { model.pendingForceSwitchProfileID != nil },
                set: { if !$0 { model.clearForceSwitchPrompt() } }
            )
        ) {
            Button("Force Switch", role: .destructive) {
                model.confirmForceSwitch()
            }
            Button("Cancel", role: .cancel) {
                model.clearForceSwitchPrompt()
            }
        } message: {
            Text("""
            Codex-related processes are still running:
            \(model.pendingForceSwitchProcesses.map { "\($0.displayName) [\($0.pid)]" }.joined(separator: "\n"))

            A force switch updates the live auth file, but those processes may keep their old credentials until they restart.
            """)
        }
        .alert(
            "Delete Saved Profile?",
            isPresented: Binding(
                get: { model.pendingDeleteProfile != nil },
                set: { if !$0 { model.pendingDeleteProfile = nil } }
            ),
            presenting: model.pendingDeleteProfile
        ) { _ in
            Button("Delete", role: .destructive) {
                model.confirmDeleteSelectedProfile()
            }
            Button("Cancel", role: .cancel) {
                model.pendingDeleteProfile = nil
            }
        } message: { profile in
            Text(deleteMessage(for: profile))
        }
        .sheet(
            isPresented: $isShowingRenameSheet,
            onDismiss: clearRenameState
        ) {
            RenameProfileSheet(
                displayName: $renameDisplayName,
                onCancel: dismissRenameSheet,
                onSave: saveRename
            )
        }
        .onAppear {
            model.load()
            runtime.load()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Codex Account Hub")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Text("Import a Codex `auth.json`, keep saved profiles here, and switch accounts from the menu bar whenever you need them.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            Text("Closing this window keeps Codex Account Hub running in the menu bar. Use the menu bar icon to reopen the app, change settings, or quit.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Where to find your Codex profile on macOS")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(displayedAuthPath)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(theme.textPrimary)

                Text("In Finder, press Shift-Command-G and paste this path.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.elevatedInsetBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.elevatedInsetBorder, lineWidth: 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(tint: theme.primaryCardTint))
    }

    private var actionsCard: some View {
        HStack(spacing: 10) {
            Button {
                model.importCurrentEffectiveAuth()
            } label: {
                Label("Import Current Session", systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                if let url = openJSONPanel() {
                    model.importProfile(from: url)
                }
            } label: {
                Label("Import File…", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Profiles")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if let activeProfileName = model.activeProfileName {
                    Text(activeProfileName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.activeBadgeBackground)
                        .foregroundStyle(theme.activeBadgeForeground)
                        .clipShape(Capsule())
                }
            }

            if model.sortedProfiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles Yet",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Use one of the import buttons above to save your first Codex profile.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(model.sortedProfiles) { profile in
                        ProfileListRow(
                            profile: profile,
                            isActive: model.isActive(profile),
                            onActivate: { activateProfile(profile) },
                            onRename: { beginRename(profile) },
                            onDelete: { requestDelete(for: profile) }
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(tint: theme.secondaryCardTint))
    }

    private var displayedAuthPath: String {
        let path = model.resolvedLocation.authFileURL.path
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path

        guard path.hasPrefix(homePath) else {
            return path
        }

        return "~" + path.dropFirst(homePath.count)
    }

    private func activateProfile(_ profile: ProfileMetadata) {
        guard !model.isActive(profile) else { return }
        model.selectProfile(id: profile.id)
        model.attemptSwitch(profileID: profile.id)
    }

    private func beginRename(_ profile: ProfileMetadata) {
        model.selectProfile(id: profile.id)
        editedProfileID = profile.id
        renameDisplayName = profile.displayName
        isShowingRenameSheet = true
    }

    private func requestDelete(for profile: ProfileMetadata) {
        model.selectProfile(id: profile.id)
        model.requestDeleteSelectedProfile()
    }

    private func saveRename() {
        guard let editedProfileID else {
            dismissRenameSheet()
            return
        }

        model.selectProfile(id: editedProfileID)
        model.draft.displayName = renameDisplayName
        model.saveDraft()

        let trimmedDisplayName = renameDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedDisplayName = model.profiles.first(where: { $0.id == editedProfileID })?.displayName
        if storedDisplayName == trimmedDisplayName {
            dismissRenameSheet()
        }
    }

    private func dismissRenameSheet() {
        isShowingRenameSheet = false
        clearRenameState()
    }

    private func clearRenameState() {
        editedProfileID = nil
        renameDisplayName = ""
    }

    private func deleteMessage(for profile: ProfileMetadata) -> String {
        if model.isActive(profile) {
            return "Delete \"\(profile.displayName)\" from saved profiles? The live auth file will stay unchanged until you switch again."
        }

        return "Delete \"\(profile.displayName)\" from saved profiles?"
    }

    private var windowBackground: some View {
        theme.windowBackground.ignoresSafeArea()
    }

    private func cardBackground(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.12),
                                theme.cardHighlight
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(theme.cardBorder, lineWidth: 1)
            }
            .shadow(color: theme.shadow, radius: 16, x: 0, y: 10)
    }

    private var theme: AppTheme.Palette {
        AppTheme.palette(for: colorScheme)
    }

    private func openJSONPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private struct ProfileListRow: View {
    let profile: ProfileMetadata
    let isActive: Bool
    let onActivate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onActivate) {
                HStack(spacing: 12) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isActive ? theme.activeBadgeForeground : theme.textSecondary)

                    Text(profile.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if isActive {
                        Text("Active")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.activeBadgeBackground)
                            .foregroundStyle(theme.activeBadgeForeground)
                            .clipShape(Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Rename…", action: onRename)
                Button("Delete…", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(theme.iconButtonBackground)
                    .clipShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Manage \(profile.displayName)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? theme.rowActiveBackground : theme.rowInactiveBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive ? theme.rowActiveBorder : theme.rowInactiveBorder, lineWidth: 1)
        }
    }

    private var theme: AppTheme.Palette {
        AppTheme.palette(for: colorScheme)
    }
}

private struct RenameProfileSheet: View {
    @Binding var displayName: String
    let onCancel: () -> Void
    let onSave: () -> Void
    @FocusState private var isDisplayNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rename Profile")
                .font(.title3.weight(.semibold))

            TextField("Profile title", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .focused($isDisplayNameFocused)
                .onSubmit(onSave)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            isDisplayNameFocused = true
        }
    }
}
