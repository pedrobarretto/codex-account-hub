import SwiftUI

enum AppSceneID {
    static let mainWindow = "main-window"
}

@main
struct CodexAccountHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @State private var runtime = AppRuntime()

    var body: some Scene {
        Window("Codex Account Hub", id: AppSceneID.mainWindow) {
            ContentView(model: model, runtime: runtime)
        }
        .defaultSize(width: 460, height: 620)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarProfilesView(model: model, runtime: runtime)
        } label: {
            Label("Codex Account Hub", image: "MenuBarIcon")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model, runtime: runtime)
        }
    }
}
