# Codex Account Hub

<img src="CodexAccountHub/Assets.xcassets/AppIcon.appiconset/appicon-256.png" alt="Codex Account Hub icon" width="96" />

Codex Account Hub is a macOS-only SwiftUI menu bar app for managing multiple local Codex account profiles and safely switching the live `auth.json` used by Codex CLI and the Codex desktop app.

## Status
- macOS-only local utility
- no sample credentials or auth payloads are checked into this repo
- tested with:
  - `swift test` in `Packages/CodexAuthCore`
  - `xcodebuild -project CodexAccountHub.xcodeproj -scheme CodexAccountHub -destination 'platform=macOS' test`

## What It Does
- stores multiple local Codex auth profiles
- keeps auth payloads in Keychain and profile metadata in Application Support
- imports an existing `auth.json`
- lets you create, edit, duplicate, and delete profiles
- resolves the effective live auth location with this precedence:
  1. explicit in-app override
  2. `CODEX_HOME` visible to the app process
  3. `~/.codex`
- backs up the previous live auth file before switching
- atomically writes the selected profile to the effective live auth file
- detects Codex desktop, helper, app-server, and CLI processes before switching
- blocks switching by default when Codex is running, with an explicit force-switch path

## Repo Layout
- `CodexAccountHub/`: SwiftUI macOS app target
- `CodexAccountHubTests/`: Xcode project smoke tests
- `Packages/CodexAuthCore/`: testable switching, storage, and process logic
- `docs/specs/`: product, technical, execution, decisions, and progress docs
- `scripts/generate_xcodeproj.rb`: regenerates the checked-in Xcode project

## Requirements
- macOS 14+
- Xcode 26.2 or newer
- Swift 6.2 or newer
- Ruby with the `xcodeproj` gem if you want to regenerate the Xcode project
- local access to your Codex home and Keychain

## Quick Start
Clone the repo and open the checked-in project:

```bash
git clone https://github.com/pedrobarretto/codex-account-hub.git
cd codex-account-hub
open CodexAccountHub.xcodeproj
```

Build and test from the terminal if you prefer:

```bash
xcodebuild -project CodexAccountHub.xcodeproj -scheme CodexAccountHub -destination 'platform=macOS' test
xcodebuild -project CodexAccountHub.xcodeproj -scheme CodexAccountHub -destination 'platform=macOS' build
```

The built app lands under Xcode DerivedData, for example:

```bash
open ~/Library/Developer/Xcode/DerivedData/CodexAccountHub-*/Build/Products/Debug/CodexAccountHub.app
```

## Regenerate The Xcode Project
The repo includes a checked-in `CodexAccountHub.xcodeproj`, but you can recreate it from source definitions when needed.

Install the Ruby dependency once:

```bash
gem install xcodeproj
```

Then regenerate:

```bash
ruby scripts/generate_xcodeproj.rb
```

## First Run
1. Launch the app.
2. Use the menu bar icon to open the main window when you need it.
3. Import your current effective `auth.json` or choose another local auth file.
4. Save one or more named profiles.
5. Click a saved profile to make it active.
6. Restart any already-running Codex processes if you used force-switching.

## Test Commands
Core package tests:

```bash
cd Packages/CodexAuthCore
swift test
```

Project-level smoke tests:

```bash
xcodebuild -project CodexAccountHub.xcodeproj -scheme CodexAccountHub -destination 'platform=macOS' test
```

## Storage
- auth secrets: macOS Keychain, generic password items under service `dev.codex-account-hub.profile`
- profile metadata: `~/Library/Application Support/CodexAccountHub/profiles.json`
- backups of replaced live auth files: `~/Library/Application Support/CodexAccountHub/backups/`
- explicit Codex home override: `UserDefaults`

## Security Notes
- this repo does not include any real `auth.json` payloads, API keys, or exported Keychain data
- imported auth payloads are stored locally in the macOS Keychain, not in the repository
- profile metadata stored on disk does not include the raw auth JSON blob

## Important Behavior Notes
- Finder-launched apps usually do not inherit shell-only `CODEX_HOME` exports. Use the app’s explicit Codex home override when you need a different live target.
- The app is designed to stay resident in the menu bar after you close its windows. Use the menu bar menu to reopen the app, change settings, enable Launch at Login, or quit.
- The app intentionally preserves unknown `auth.json` keys by storing the full raw JSON payload.
- The app blocks switching when Codex desktop, helper, app-server, or CLI processes are running. You can force-switch, but already-running Codex processes may keep their old credentials until restarted.
- This is a local personal tool. It is unsandboxed on purpose and is not intended for Mac App Store distribution.
