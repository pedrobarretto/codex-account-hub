import AppKit
import Observation
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case disabled
    case enabled
    case requiresApproval

    var isToggleOn: Bool {
        self != .disabled
    }

    var detailText: String? {
        switch self {
        case .disabled:
            return nil
        case .enabled:
            return "Codex Account Hub will relaunch automatically the next time you log into macOS."
        case .requiresApproval:
            return "macOS still requires approval in System Settings > General > Login Items."
        }
    }
}

protocol LaunchAtLoginControlling {
    func currentState() -> LaunchAtLoginState
    func setEnabled(_ enabled: Bool) throws
}

struct SMAppServiceController: LaunchAtLoginControlling {
    private let service = SMAppService.mainApp

    func currentState() -> LaunchAtLoginState {
        switch service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}

protocol AppActivating {
    func activate()
}

struct NSApplicationActivator: AppActivating {
    func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

protocol AppTerminating {
    func terminate()
}

struct NSApplicationTerminator: AppTerminating {
    func terminate() {
        NSApp.terminate(nil)
    }
}

@MainActor
protocol AppRuntimeControlling: AnyObject {
    var launchAtLoginState: LaunchAtLoginState { get }
    var bannerMessage: BannerMessage? { get set }
    func load()
    func setLaunchAtLoginEnabled(_ enabled: Bool)
    func openMainWindow(_ openWindow: () -> Void)
    func openSettings(_ openSettings: () -> Void)
    func quit()
    func dismissBanner()
}

@MainActor
@Observable
final class AppRuntime: AppRuntimeControlling {
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let activator: any AppActivating
    private let terminator: any AppTerminating

    var launchAtLoginState: LaunchAtLoginState = .disabled
    var bannerMessage: BannerMessage?

    init(
        launchAtLoginController: any LaunchAtLoginControlling = SMAppServiceController(),
        activator: any AppActivating = NSApplicationActivator(),
        terminator: any AppTerminating = NSApplicationTerminator()
    ) {
        self.launchAtLoginController = launchAtLoginController
        self.activator = activator
        self.terminator = terminator
    }

    func load() {
        refreshLaunchAtLoginState()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        let previousState = launchAtLoginState

        do {
            try launchAtLoginController.setEnabled(enabled)
            refreshLaunchAtLoginState()

            if enabled {
                switch launchAtLoginState {
                case .enabled:
                    bannerMessage = BannerMessage(kind: .success, text: "Launch at Login is enabled.")
                case .requiresApproval:
                    bannerMessage = BannerMessage(kind: .warning, text: "Launch at Login was registered, but macOS still requires approval in System Settings.")
                case .disabled:
                    bannerMessage = BannerMessage(kind: .warning, text: "Launch at Login did not stay enabled. Check Login Items settings and the app signature.")
                }
            } else {
                bannerMessage = BannerMessage(kind: .info, text: "Launch at Login is disabled.")
            }
        } catch {
            launchAtLoginState = previousState
            bannerMessage = BannerMessage(kind: .error, text: "Couldn't update Launch at Login: \(error.localizedDescription)")
        }
    }

    func openMainWindow(_ openWindow: () -> Void) {
        openWindow()
        activator.activate()
    }

    func openSettings(_ openSettings: () -> Void) {
        openSettings()
        activator.activate()
    }

    func quit() {
        terminator.terminate()
    }

    func dismissBanner() {
        bannerMessage = nil
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginState = launchAtLoginController.currentState()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
