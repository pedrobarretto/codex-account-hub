import SwiftUI

enum AppSceneID {
    static let mainWindow = "main-window"
}

@main
struct CodexAccountHubApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: AppSceneID.mainWindow) {
            ContentView(model: model)
        }
        .defaultSize(width: 460, height: 620)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarProfilesView(model: model)
        } label: {
            Label("Codex Account Hub", image: "MenuBarIcon")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
    }
}
