# Codex Account Hub Decisions Log

## 2026-04-06

### New Native macOS App
- Decision: Scaffold a new SwiftUI macOS app in this repo rather than adapting existing code.
- Reason: The workspace was empty, and the product requirement explicitly prefers a native macOS app.

### Shared Core Package
- Decision: Put switching and storage logic in `Packages/CodexAuthCore`.
- Reason: The core logic needs unit tests and should stay independent of SwiftUI.

### Keychain Stores Full Auth Blob
- Decision: Store the full auth JSON blob per profile in Keychain rather than splitting token fields.
- Reason: This preserves unknown fields and avoids reverse-engineering undocumented auth semantics.

### Raw JSON Editing
- Decision: The UI edits raw `auth.json` payload text instead of presenting a field-based token editor.
- Reason: The file format is intentionally preserved as a JSON object with minimal assumptions.

### Auth Path Override
- Decision: Add an explicit in-app Codex home override.
- Reason: Finder-launched apps commonly do not inherit shell-only environment variables like `CODEX_HOME`.

### Unsandboxed App
- Decision: Keep the app unsandboxed.
- Reason: It needs to inspect local processes and read/write the live Codex auth path under the user home directory.

### Repo-Owned Project Generation
- Decision: Generate the checked-in Xcode project from `scripts/generate_xcodeproj.rb`.
- Reason: It keeps the project reproducible and reviewable without hand-maintaining raw `pbxproj` internals.

### Non-Hosted Project Smoke Tests
- Decision: Keep the Xcode project test target as a non-hosted smoke suite and keep the deeper behavioral tests in `CodexAuthCore`.
- Reason: Hosted app tests added complexity without adding coverage proportional to the MVP, while the package already contains the important switching and storage tests.
