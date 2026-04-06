import XCTest
@testable import CodexAuthCore

final class AuthPathResolverTests: XCTestCase {
    func testOverrideWins() {
        let resolver = AuthPathResolver(
            environmentProvider: { ["CODEX_HOME": "/tmp/from-env"] },
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/tester", isDirectory: true) }
        )

        let resolved = resolver.resolveAuthLocation(overrideCodexHome: URL(fileURLWithPath: "/tmp/override", isDirectory: true))
        XCTAssertEqual(resolved.source, .override)
        XCTAssertEqual(resolved.authFileURL.path, "/tmp/override/auth.json")
    }

    func testEnvironmentWinsOverDefault() {
        let resolver = AuthPathResolver(
            environmentProvider: { ["CODEX_HOME": "/tmp/from-env"] },
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/tester", isDirectory: true) }
        )

        let resolved = resolver.resolveAuthLocation()
        XCTAssertEqual(resolved.source, .environment)
        XCTAssertEqual(resolved.effectiveCodexHome.path, "/tmp/from-env")
    }

    func testFallsBackToDefault() {
        let resolver = AuthPathResolver(
            environmentProvider: { [:] },
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/tester", isDirectory: true) }
        )

        let resolved = resolver.resolveAuthLocation()
        XCTAssertEqual(resolved.source, .default)
        XCTAssertEqual(resolved.authFileURL.path, "/Users/tester/.codex/auth.json")
    }
}
