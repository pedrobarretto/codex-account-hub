import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @Bindable var runtime: AppRuntime

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text("Codex Account Hub runs as a menu bar utility. Use these settings to control startup behavior and the effective `CODEX_HOME` path it manages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let banner = runtime.bannerMessage {
                BannerMessageCard(banner: banner) {
                    runtime.dismissBanner()
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("App Behavior")
                    .font(.headline)

                Toggle("Launch at Login", isOn: launchAtLoginBinding)

                Text("Closing the main window keeps the app resident in the menu bar until you explicitly quit it from the menu bar menu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let detailText = runtime.launchAtLoginState.detailText {
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(runtime.launchAtLoginState == .requiresApproval ? .orange : .secondary)
                }
            }
            .padding(18)
            .background(settingsCard)

            VStack(alignment: .leading, spacing: 14) {
                Text("Codex Home Override")
                    .font(.headline)

                TextField("Codex home path", text: $model.codexHomeOverridePath)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button("Choose Folder") {
                        if let url = openFolderPanel() {
                            model.codexHomeOverridePath = url.path
                        }
                    }

                    Button("Apply") {
                        model.applyCodexHomeOverride()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear") {
                        model.clearCodexHomeOverride()
                    }
                }
            }
            .padding(18)
            .background(settingsCard)

            VStack(alignment: .leading, spacing: 12) {
                Text("Effective Target")
                    .font(.headline)

                SettingsValueRow(label: "Codex home", value: model.resolvedLocation.effectiveCodexHome.path)
                SettingsValueRow(label: "Auth file", value: model.resolvedLocation.authFileURL.path)
            }
            .padding(18)
            .background(settingsCard)
        }
        .padding(24)
        .frame(width: 620)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.96, blue: 0.98),
                    Color(red: 0.92, green: 0.94, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            runtime.load()
        }
    }

    private var settingsCard: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.45), lineWidth: 1)
            }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { runtime.launchAtLoginState.isToggleOn },
            set: { runtime.setLaunchAtLoginEnabled($0) }
        )
    }

    private func openFolderPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private struct SettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
