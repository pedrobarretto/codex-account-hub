import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @Bindable var runtime: AppRuntime
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Codex Account Hub runs as a menu bar utility. Use these settings to control startup behavior and the effective `CODEX_HOME` path it manages.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            if let banner = runtime.bannerMessage {
                BannerMessageCard(banner: banner) {
                    runtime.dismissBanner()
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Appearance")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                Picker("Theme", selection: $model.themeMode) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("System follows macOS appearance. Light and Dark override it for this app.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(18)
            .background(settingsCard)

            VStack(alignment: .leading, spacing: 14) {
                Text("App Behavior")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                Toggle("Launch at Login", isOn: launchAtLoginBinding)

                Text("Closing the main window keeps the app resident in the menu bar until you explicitly quit it from the menu bar menu.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)

                if let detailText = runtime.launchAtLoginState.detailText {
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(runtime.launchAtLoginState == .requiresApproval ? warningColors.symbol : theme.textSecondary)
                }
            }
            .padding(18)
            .background(settingsCard)

            VStack(alignment: .leading, spacing: 14) {
                Text("Codex Home Override")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

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
                    .foregroundStyle(theme.textPrimary)

                SettingsValueRow(label: "Codex home", value: model.resolvedLocation.effectiveCodexHome.path)
                SettingsValueRow(label: "Auth file", value: model.resolvedLocation.authFileURL.path)
            }
            .padding(18)
            .background(settingsCard)
        }
        .padding(24)
        .frame(width: 620)
        .background(
            theme.windowBackground.ignoresSafeArea()
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
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.secondaryCardTint.opacity(0.12),
                                theme.cardHighlight
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(theme.cardBorder, lineWidth: 1)
            }
            .shadow(color: theme.shadow, radius: 14, x: 0, y: 8)
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

    private var theme: AppTheme.Palette {
        AppTheme.palette(for: colorScheme)
    }

    private var warningColors: AppTheme.BannerColors {
        AppTheme.bannerColors(for: .warning, in: theme)
    }
}

private struct SettingsValueRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(theme.textPrimary)
        }
    }

    private var theme: AppTheme.Palette {
        AppTheme.palette(for: colorScheme)
    }
}
