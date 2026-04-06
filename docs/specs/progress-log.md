# Codex Account Hub Progress Log

## 2026-04-06

### Kickoff
- Inspected the workspace and confirmed the repo was empty.
- Confirmed the local default live auth path is `~/.codex/auth.json` when `CODEX_HOME` is not visible.
- Sampled the current auth file structure at the key level only and confirmed it is a JSON object.
- Inspected local process names and confirmed Codex desktop runs as `Codex.app` with helper and `codex app-server` processes.

### Milestone 1 Started
- Created the spec documents under `docs/specs/`.
- Locked the initial architecture: SwiftUI macOS app plus shared `CodexAuthCore` package.
- Locked the storage model: Keychain for auth payloads, Application Support JSON for metadata, UserDefaults for explicit override, Application Support backups for live auth snapshots.

### Milestone 2 Completed
- Scaffolded `Packages/CodexAuthCore`.
- Implemented auth payload parsing and canonical comparison.
- Implemented auth path resolution with override, environment, and default precedence.
- Implemented metadata storage in Application Support JSON.
- Implemented Keychain-backed secret storage.
- Implemented process inspection using `NSWorkspace` plus `ps`.
- Implemented switch coordination with backup, atomic write, and readback verification.
- Added package tests for parsing, storage, process matching, switching, and active-profile matching.
- Fixed a process-detection bug that would have matched the manager app itself.

### Milestone 3 Completed
- Built the native SwiftUI macOS app shell.
- Added profile list, detail editor, raw JSON editor, import actions, duplicate, delete, and switch actions.
- Added status surfaces for effective auth path, live auth state, and running process state.
- Added force-switch confirmation and delete confirmation flows.
- Added a settings view for the explicit Codex home override.

### Milestone 4 Completed
- Wired the app to real Keychain persistence and Application Support paths.
- Wired live active-profile detection against the on-disk auth file.
- Wired backups and switching status messages into the app flow.
- Generated a repo-owned Xcode project and shared schemes from `scripts/generate_xcodeproj.rb`.

### Milestone 5 Completed
- Added root README and local development instructions.
- Added a root `.gitignore`.
- Verified `swift test` passes in `Packages/CodexAuthCore`.
- Verified `xcodebuild -project CodexAccountHub.xcodeproj -scheme CodexAccountHub -destination 'platform=macOS' test` passes.
