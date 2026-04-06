import AppKit
import CodexAuthCore
import SwiftUI

struct MenuBarProfilesView: View {
    @Bindable var model: AppModel
    @Bindable var runtime: AppRuntime
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Section("Profiles") {
                if model.sortedProfiles.isEmpty {
                    Text("No saved profiles yet")
                } else {
                    ForEach(model.sortedProfiles) { profile in
                        Button {
                            switchProfile(profile)
                        } label: {
                            if model.isActive(profile) {
                                Label(profile.displayName, systemImage: "checkmark")
                            } else {
                                Text(profile.displayName)
                            }
                        }
                    }
                }
            }

            if let banner = runtime.bannerMessage {
                Divider()

                Section("App Status") {
                    Text(banner.text)
                        .font(.caption)
                }
            }

            Divider()

            Button("Open Account Hub…") {
                runtime.openMainWindow {
                    model.load()
                    openWindow(id: AppSceneID.mainWindow)
                }
            }

            Button("Settings…") {
                runtime.openSettings {
                    openSettings()
                }
            }

            Toggle("Launch at Login", isOn: launchAtLoginBinding)

            if let detailText = runtime.launchAtLoginState.detailText {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit") {
                runtime.quit()
            }
        }
        .onAppear {
            model.load()
            runtime.load()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { runtime.launchAtLoginState.isToggleOn },
            set: { runtime.setLaunchAtLoginEnabled($0) }
        )
    }

    private func switchProfile(_ profile: ProfileMetadata) {
        guard !model.isActive(profile) else { return }

        do {
            let preflight = try model.preflightSwitch(profileID: profile.id)
            if preflight.blockingProcesses.isEmpty || confirmForceSwitch(for: profile, processes: preflight.blockingProcesses) {
                try model.switchProfileImmediately(
                    profileID: profile.id,
                    allowUnsafe: !preflight.blockingProcesses.isEmpty
                )
            }
        } catch {
            model.bannerMessage = BannerMessage(kind: .error, text: error.localizedDescription)
        }
    }

    private func confirmForceSwitch(for profile: ProfileMetadata, processes: [RunningProcess]) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Force switch to \(profile.displayName)?"
        alert.informativeText = """
        Codex-related processes are still running:
        \(processes.map { "\($0.displayName) [\($0.pid)]" }.joined(separator: "\n"))

        The auth file will be updated, but those processes may keep the old credentials until they restart.
        """
        alert.addButton(withTitle: "Force Switch")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
