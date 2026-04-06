# Codex Account Hub Technical Design

## Architecture
The repo contains two code layers:

1. `Packages/CodexAuthCore`
   - Pure Swift package containing parsing, storage, Keychain, process inspection, auth path resolution, and switching logic.
   - Primary target for automated tests.

2. `CodexAccountHub` macOS app target
   - SwiftUI shell and app state orchestration.
   - Depends on `CodexAuthCore`.
   - Keeps UI code thin and delegates business logic to the package.

The Xcode project is checked into the repo and can be regenerated from `scripts/generate_xcodeproj.rb`.

## App Structure
### Core Package Types
- `AuthPayload`
  - Owns raw JSON data and canonical normalized JSON data.
  - Validates that payloads are JSON objects.
  - Exposes lightweight inspection helpers for `auth_mode`, `OPENAI_API_KEY`, `last_refresh`, and `tokens`.
- `AuthPathResolver`
  - Resolves the effective Codex home and `auth.json` location.
  - Uses precedence: explicit override, visible environment variable, default `~/.codex`.
- `ProfileMetadata`
  - `id`, `displayName`, `notes`, `createdAt`, `updatedAt`, `lastImportedAt`, `lastSwitchedAt`
- `ProfileMetadataStore`
  - Reads and writes metadata JSON at `~/Library/Application Support/CodexAccountHub/profiles.json`
- `KeychainSecretsStore`
  - Stores the raw auth JSON blob in Keychain using generic password entries
- `ProcessInspector`
  - Collects visible applications via `NSWorkspace`
  - Collects helper and CLI processes via `/bin/ps -axo pid=,comm=,args=`
  - Returns `RunningProcess` matches relevant to Codex
- `SwitchCoordinator`
  - Performs preflight checks
  - Creates backups
  - Writes the target auth file atomically
  - Verifies readback
  - Coordinates metadata updates

### App Layer Types
- `AppModel`
  - `@MainActor` observable object
  - Owns list state, selected profile, editor state, current auth state, status banners, and modal presentation
- SwiftUI views
  - sidebar list
  - detail editor
  - status banner
  - process warning sheet
  - delete confirmation
  - settings form for explicit Codex home override

## Storage Model
### Sensitive Data
- Location: Keychain generic password items
- Service: `dev.codex-account-hub.profile`
- Account: profile UUID string
- Value: raw auth JSON bytes

### Non-Sensitive Data
- Location: `~/Library/Application Support/CodexAccountHub/profiles.json`
- Contains profile metadata only

### Settings
- `UserDefaults` stores explicit optional Codex home override path

### Backups
- Directory: `~/Library/Application Support/CodexAccountHub/backups/`
- Filename pattern: `auth-YYYYMMDD-HHMMSS.json`
- Backup creation is best-effort but failure aborts switching to avoid silent risk

## Auth File Model
- Supported live auth representation: any JSON object
- Unknown keys are preserved exactly by storing and rewriting the raw JSON payload after canonical validation
- Canonical comparison uses `JSONSerialization` with sorted keys to compare semantic equality between profiles and the live auth file
- Known fields are inspected only for display or lightweight validation:
  - `auth_mode`
  - `OPENAI_API_KEY`
  - `last_refresh`
  - `tokens`
- The implementation does not depend on undocumented token subfield semantics

## Active Profile Detection
1. Resolve the live auth path
2. Read and validate the live `auth.json` if present
3. Normalize it to canonical JSON data
4. Normalize all stored profile payloads
5. If exactly one matches, mark it active
6. If none match, show external/unmanaged auth
7. If multiple match, show ambiguous active state and do not silently choose one

## Process Detection Strategy
### App Process Source
- `NSWorkspace.shared.runningApplications`
- Used for visible app binaries such as `Codex.app`

### System Process Source
- Spawn `/bin/ps -axo pid=,comm=,args=`
- Parse helper, background, and CLI processes not exposed cleanly via `NSWorkspace`

### Codex Match Rules
- app name or bundle path contains `Codex.app`
- process name contains `Codex Helper`
- args contain `/Applications/Codex.app/`
- args contain `codex app-server`
- executable basename equals `codex`

### Switching Behavior
- Default: block switching when matching processes exist
- Override path: explicit user-confirmed force-switch allowed
- UI copy warns that already-running processes may not pick up the new account until restarted

## Switching Algorithm
1. Resolve the effective auth path
2. Load the selected profile’s auth blob from Keychain
3. Parse and canonicalize as `AuthPayload`
4. Inspect running Codex-related processes
5. Return `SwitchPreflightResult` if switching is blocked
6. Ensure target parent directory exists
7. If a live auth file exists, copy it to the backup directory with timestamped name
8. Create a temp file in the target directory
9. Write payload bytes to the temp file
10. Apply `0600` permissions
11. Atomically replace the live `auth.json`
12. Re-read the written file and canonicalize
13. Verify exact canonical equality against the intended payload
14. Update metadata `lastSwitchedAt`
15. Refresh active profile state and surface success

## Security And Platform Notes
- The app is intentionally unsandboxed because it must access arbitrary user-home paths and inspect processes
- This is a local developer tool, not a Mac App Store target
- Keychain is the preferred storage for auth payloads
- If Keychain operations fail, the app surfaces explicit errors and does not fall back silently

## Test Strategy
### Unit Tests
- `AuthPayload`
  - accepts object JSON
  - rejects arrays and scalars
  - canonicalizes deterministically
  - preserves unknown structure
- `AuthPathResolver`
  - override precedence
  - environment precedence
  - default path fallback
- `ProfileMetadataStore`
  - round-trip save/load
  - empty and missing store handling
  - corruption detection
- `ProcessInspector`
  - parse mocked `ps` output
  - detect desktop, helper, app-server, and CLI matches
  - ignore unrelated processes
- `SwitchCoordinator`
  - blocks on running processes
  - allows force-switch
  - creates backups
  - writes atomically
  - verifies readback
  - surfaces file and validation errors
- active profile matching
  - exact match
  - no match
  - multiple match

### Build Verification
- `swift test` for `CodexAuthCore`
- `xcodebuild` build/test for the app project
- project-level smoke tests stay lightweight and focus on package integration inside the app project; the detailed logic coverage remains in `CodexAuthCore`

## Chosen Defaults
- App name: `Codex Account Hub`
- Bundle identifier: `dev.codex-account-hub`
- Minimum deployment target: macOS 14.0
- Settings override is used because Finder-launched apps generally cannot see shell-only `CODEX_HOME`
