@testable import CodexAccountHub
import XCTest

@MainActor
final class AppRuntimeTests: XCTestCase {
    func testLoadReflectsLaunchAtLoginStateFromController() {
        let runtime = AppRuntime(
            launchAtLoginController: StubLaunchAtLoginController(state: .enabled),
            activator: RecordingActivator(),
            terminator: RecordingTerminator()
        )

        runtime.load()

        XCTAssertEqual(runtime.launchAtLoginState, .enabled)
    }

    func testEnableLaunchAtLoginSurfacesApprovalState() {
        let controller = StubLaunchAtLoginController(state: .disabled)
        controller.stateAfterMutation = .requiresApproval

        let runtime = AppRuntime(
            launchAtLoginController: controller,
            activator: RecordingActivator(),
            terminator: RecordingTerminator()
        )

        runtime.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(runtime.launchAtLoginState, .requiresApproval)
        XCTAssertEqual(runtime.bannerMessage?.kind, .warning)
    }

    func testOpenMainWindowActivatesAppAfterOpenAction() {
        let events = EventLog()
        let activator = RecordingActivator(events: events)
        let runtime = AppRuntime(
            launchAtLoginController: StubLaunchAtLoginController(state: .disabled),
            activator: activator,
            terminator: RecordingTerminator()
        )

        runtime.openMainWindow {
            events.values.append("open")
        }

        XCTAssertEqual(events.values, ["open", "activate"])
    }
}

private final class StubLaunchAtLoginController: LaunchAtLoginControlling {
    var state: LaunchAtLoginState
    var stateAfterMutation: LaunchAtLoginState?

    init(state: LaunchAtLoginState) {
        self.state = state
    }

    func currentState() -> LaunchAtLoginState {
        state
    }

    func setEnabled(_ enabled: Bool) throws {
        state = stateAfterMutation ?? (enabled ? .enabled : .disabled)
    }
}

private final class EventLog {
    var values: [String] = []
}

private final class RecordingActivator: AppActivating {
    private let events: EventLog

    init(events: EventLog = EventLog()) {
        self.events = events
    }

    func activate() {
        events.values.append("activate")
    }
}

private final class RecordingTerminator: AppTerminating {
    func terminate() {}
}
