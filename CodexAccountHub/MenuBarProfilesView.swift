import AppKit
import CodexAuthCore
import SwiftUI

struct MenuBarProfilesView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

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

            Divider()

            Button("Open App…") {
                openWindow(id: AppSceneID.mainWindow)
            }
        }
        .onAppear {
            model.load()
        }
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
