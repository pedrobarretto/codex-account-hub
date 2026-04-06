import AppKit
import CodexAuthCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel
    @Bindable var runtime: AppRuntime
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

            Text("Import a Codex `auth.json`, keep saved profiles here, and switch accounts from the menu bar whenever you need them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Closing this window keeps Codex Account Hub running in the menu bar. Use the menu bar icon to reopen the app, change settings, or quit.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Where to find your Codex profile on macOS")
                    .font(.subheadline.weight(.semibold))

                Text(displayedAuthPath)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)

                Text("In Finder, press Shift-Command-G and paste this path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(tint: Color(red: 0.13, green: 0.33, blue: 0.57)))
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
                Spacer()
                if let activeProfileName = model.activeProfileName {
                    Text(activeProfileName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.green.opacity(0.14))
                        .foregroundStyle(.green)
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
        .background(cardBackground(tint: Color(red: 0.19, green: 0.21, blue: 0.24)))
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
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.97, blue: 0.98),
                Color(red: 0.92, green: 0.94, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
                                .white.opacity(0.34)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 10)
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

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onActivate) {
                HStack(spacing: 12) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isActive ? .green : .secondary)

                    Text(profile.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    if isActive {
                        Text("Active")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.green.opacity(0.14))
                            .foregroundStyle(.green)
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
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.68))
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
                .fill(isActive ? .green.opacity(0.1) : .white.opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive ? .green.opacity(0.22) : .white.opacity(0.3), lineWidth: 1)
        }
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
