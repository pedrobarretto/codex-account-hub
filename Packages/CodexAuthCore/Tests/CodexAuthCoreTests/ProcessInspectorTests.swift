import XCTest
@testable import CodexAuthCore

private struct StubWorkspaceProvider: WorkspaceApplicationProviding {
    let apps: [WorkspaceApplicationSnapshot]
    func runningApplications() -> [WorkspaceApplicationSnapshot] { apps }
}

private struct StubProcessRunner: ProcessCommandRunning {
    let output: String
    func run(_ launchPath: String, arguments: [String]) throws -> String { output }
}

private final class LockedCommandResult: @unchecked Sendable {
    private let lock = NSLock()
    private var output: String?
    private var error: Error?

    func store(output: String) {
        lock.lock()
        self.output = output
        lock.unlock()
    }

    func store(error: Error) {
        lock.lock()
        self.error = error
        lock.unlock()
    }

    func snapshot() -> (output: String?, error: Error?) {
        lock.lock()
        let snapshot = (output, error)
        lock.unlock()
        return snapshot
    }
}

final class ProcessInspectorTests: XCTestCase {
    @MainActor
    func testDefaultProcessCommandRunnerHandlesLargeOutput() {
        let runner = DefaultProcessCommandRunner()
        let expectedLineCount = 40000
        let command = "for i in $(seq 1 \(expectedLineCount)); do printf 'codex-line-%s\\n' \"$i\"; done"
        let finished = expectation(description: "runner finished")
        let result = LockedCommandResult()

        DispatchQueue.global(qos: .userInitiated).async {
            defer { finished.fulfill() }
            do {
                result.store(output: try runner.run("/bin/sh", arguments: ["-c", command]))
            } catch {
                result.store(error: error)
            }
        }

        waitForExpectations(timeout: 5)
        let snapshot = result.snapshot()
        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.output?.split(whereSeparator: \.isNewline).count, expectedLineCount)
    }

    func testParsesAndMatchesCodexProcesses() throws {
        let inspector = ProcessInspector(
            workspaceProvider: StubWorkspaceProvider(
                apps: [
                    WorkspaceApplicationSnapshot(
                        pid: 100,
                        localizedName: "Codex",
                        bundleURL: URL(fileURLWithPath: "/Applications/Codex.app"),
                        executableURL: URL(fileURLWithPath: "/Applications/Codex.app/Contents/MacOS/Codex")
                    )
                ]
            ),
            commandRunner: StubProcessRunner(output: """
              101 /Applications/Co /Applications/Codex.app/Contents/Frameworks/Codex Helper.app/Contents/MacOS/Codex Helper --type=gpu-process
              102 codex codex app-server --analytics-default-enabled
              103 codex /usr/local/bin/codex --dangerously-skip-permissions
              104 zsh zsh -lc echo hello
            """)
        )

        let processes = try inspector.codexProcesses()
        XCTAssertEqual(processes.count, 4)
        XCTAssertTrue(processes.contains(where: { $0.matchReason.contains("desktop") }))
        XCTAssertTrue(processes.contains(where: { $0.matchReason.contains("helper") }))
        XCTAssertTrue(processes.contains(where: { $0.matchReason.contains("app server") }))
        XCTAssertTrue(processes.contains(where: { $0.matchReason.contains("CLI") }))
    }

    func testParsePSOutputIgnoresMalformedLines() {
        let rows = ProcessInspector.parsePSOutput("""
        invalid line
        120 codex codex app-server
        """)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.pid, 120)
    }

    func testDoesNotMatchCodexAccountHubManagerApp() throws {
        let inspector = ProcessInspector(
            workspaceProvider: StubWorkspaceProvider(
                apps: [
                    WorkspaceApplicationSnapshot(
                        pid: 200,
                        localizedName: "Codex Account Hub",
                        bundleURL: URL(fileURLWithPath: "/Applications/CodexAccountHub.app"),
                        executableURL: URL(fileURLWithPath: "/Applications/CodexAccountHub.app/Contents/MacOS/CodexAccountHub")
                    )
                ]
            ),
            commandRunner: StubProcessRunner(output: "")
        )

        XCTAssertEqual(try inspector.codexProcesses(), [])
    }
}
