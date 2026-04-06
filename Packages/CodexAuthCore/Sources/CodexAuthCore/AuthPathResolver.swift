import Foundation

public protocol AuthPathResolving {
    func resolveAuthLocation(overrideCodexHome: URL?) -> ResolvedAuthLocation
}

public struct AuthPathResolver: AuthPathResolving {
    private let environmentProvider: () -> [String: String]
    private let homeDirectoryProvider: () -> URL

    public init(
        environmentProvider: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment },
        homeDirectoryProvider: @escaping () -> URL = { FileManager.default.homeDirectoryForCurrentUser }
    ) {
        self.environmentProvider = environmentProvider
        self.homeDirectoryProvider = homeDirectoryProvider
    }

    public func resolveAuthLocation(overrideCodexHome: URL? = nil) -> ResolvedAuthLocation {
        let codexHome: URL
        let source: AuthLocationSource

        if let overrideCodexHome {
            codexHome = overrideCodexHome
            source = .override
        } else if let environmentValue = environmentProvider()["CODEX_HOME"], !environmentValue.isEmpty {
            codexHome = URL(fileURLWithPath: environmentValue, isDirectory: true)
            source = .environment
        } else {
            codexHome = homeDirectoryProvider().appendingPathComponent(".codex", isDirectory: true)
            source = .default
        }

        let standardizedHome = codexHome.standardizedFileURL
        return ResolvedAuthLocation(
            effectiveCodexHome: standardizedHome,
            authFileURL: standardizedHome.appendingPathComponent("auth.json", isDirectory: false),
            source: source
        )
    }
}
