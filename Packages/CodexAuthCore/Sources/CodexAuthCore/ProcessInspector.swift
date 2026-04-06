import AppKit
import Foundation

public protocol ProcessInspecting {
    func codexProcesses() throws -> [RunningProcess]
}

public struct WorkspaceApplicationSnapshot: Equatable, Sendable {
    public let pid: Int32
    public let localizedName: String?
    public let bundleURL: URL?
    public let executableURL: URL?

    public init(pid: Int32, localizedName: String?, bundleURL: URL?, executableURL: URL?) {
        self.pid = pid
        self.localizedName = localizedName
        self.bundleURL = bundleURL
        self.executableURL = executableURL
    }
}

public protocol WorkspaceApplicationProviding {
    func runningApplications() -> [WorkspaceApplicationSnapshot]
}

public struct NSWorkspaceApplicationProvider: WorkspaceApplicationProviding {
    public init() {}

    public func runningApplications() -> [WorkspaceApplicationSnapshot] {
        NSWorkspace.shared.runningApplications.map {
            WorkspaceApplicationSnapshot(
                pid: $0.processIdentifier,
                localizedName: $0.localizedName,
                bundleURL: $0.bundleURL,
                executableURL: $0.executableURL
            )
        }
    }
}

public protocol ProcessCommandRunning {
    func run(_ launchPath: String, arguments: [String]) throws -> String
}

private final class LockedDataBuffer: @unchecked Sendable {
    private var storage = Data()
    private let lock = NSLock()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        let data = storage
        lock.unlock()
        return data
    }
}

public struct DefaultProcessCommandRunner: ProcessCommandRunning, Sendable {
    public init() {}

    public func run(_ launchPath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let outputBuffer = LockedDataBuffer()
        let errorBuffer = LockedDataBuffer()

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputBuffer.append(data)
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            errorBuffer.append(data)
        }

        try process.run()
        process.waitUntilExit()

        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil

        let remainingOutput = stdout.fileHandleForReading.readDataToEndOfFile()
        let remainingError = stderr.fileHandleForReading.readDataToEndOfFile()
        if !remainingOutput.isEmpty { outputBuffer.append(remainingOutput) }
        if !remainingError.isEmpty { errorBuffer.append(remainingError) }

        let outputData = outputBuffer.snapshot()
        let errorData = errorBuffer.snapshot()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "unknown ps failure"
            throw CodexAuthCoreError.processExecutionFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

public final class ProcessInspector: ProcessInspecting {
    private let workspaceProvider: WorkspaceApplicationProviding
    private let commandRunner: ProcessCommandRunning

    public init(
        workspaceProvider: WorkspaceApplicationProviding = NSWorkspaceApplicationProvider(),
        commandRunner: ProcessCommandRunning = DefaultProcessCommandRunner()
    ) {
        self.workspaceProvider = workspaceProvider
        self.commandRunner = commandRunner
    }

    public func codexProcesses() throws -> [RunningProcess] {
        let workspaceProcesses = workspaceProvider.runningApplications().compactMap(Self.match(workspaceApp:))
        let psOutput = try commandRunner.run("/bin/ps", arguments: ["-axo", "pid=,comm=,args="])
        let psProcesses = Self.parsePSOutput(psOutput).compactMap(Self.match(psRow:))

        var seen = Set<Int32>()
        let combined = (workspaceProcesses + psProcesses).filter { seen.insert($0.pid).inserted }
        return combined.sorted { $0.pid < $1.pid }
    }

    public static func parsePSOutput(_ output: String) -> [(pid: Int32, command: String, arguments: String)] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(maxSplits: 2, whereSeparator: \.isWhitespace)
            guard parts.count >= 2, let pid = Int32(parts[0]) else {
                return nil
            }

            let command = String(parts[1])
            let arguments = parts.count >= 3 ? String(parts[2]) : command
            return (pid, command, arguments)
        }
    }

    private static func match(workspaceApp: WorkspaceApplicationSnapshot) -> RunningProcess? {
        let localizedName = workspaceApp.localizedName ?? "Codex"
        let bundlePath = workspaceApp.bundleURL?.path ?? ""
        let executablePath = workspaceApp.executableURL?.path ?? ""
        let bundleName = workspaceApp.bundleURL?.lastPathComponent.lowercased() ?? ""
        let exactCodexApp = bundleName == "codex.app"
            || executablePath.lowercased().contains("/codex.app/")
            || localizedName.caseInsensitiveCompare("Codex") == .orderedSame

        guard exactCodexApp else {
            return nil
        }

        return RunningProcess(
            pid: workspaceApp.pid,
            displayName: localizedName,
            command: executablePath.isEmpty ? bundlePath : executablePath,
            matchReason: "Running Codex desktop application"
        )
    }

    private static func match(psRow: (pid: Int32, command: String, arguments: String)) -> RunningProcess? {
        let command = psRow.command
        let arguments = psRow.arguments
        let commandBasename = URL(fileURLWithPath: command).lastPathComponent.lowercased()
        let lowercasedArguments = arguments.lowercased()
        let lowercasedCommand = command.lowercased()

        let matchReason: String?
        let displayName: String

        if lowercasedArguments.contains("/applications/codex.app/") {
            matchReason = "Running Codex desktop helper"
            displayName = URL(fileURLWithPath: command).lastPathComponent
        } else if lowercasedArguments.contains("codex app-server") {
            matchReason = "Running Codex app server"
            displayName = "codex app-server"
        } else if lowercasedCommand.contains("codex helper") || lowercasedArguments.contains("codex helper") {
            matchReason = "Running Codex helper process"
            displayName = URL(fileURLWithPath: command).lastPathComponent
        } else if commandBasename == "codex" {
            matchReason = "Running Codex CLI process"
            displayName = "codex"
        } else {
            matchReason = nil
            displayName = URL(fileURLWithPath: command).lastPathComponent
        }

        guard let matchReason else {
            return nil
        }

        return RunningProcess(
            pid: psRow.pid,
            displayName: displayName,
            command: arguments,
            matchReason: matchReason
        )
    }
}
