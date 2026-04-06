# Codex Account Hub Product Spec

## Overview
Codex Account Hub is a personal macOS desktop app for managing multiple local Codex account profiles and safely switching which profile is active for both Codex CLI and the Codex desktop app by updating the effective `auth.json` in the user’s Codex home.

## User Problem
People using multiple Codex accounts locally have to manually swap `auth.json`, remember the correct path precedence, and avoid switching while Codex processes are running. That is error-prone, opaque, and easy to break.

## Target User
- Single local macOS user
- Comfortable with local developer tooling
- Wants local ownership and reliability, not hosted account management

## Scope
### In Scope
- macOS-native desktop app built with Swift and SwiftUI
- Manage multiple local account profiles
- Import a profile from an existing `auth.json`
- Create, edit, duplicate, and delete local profiles
- Store auth payloads in Keychain when practical
- Store profile metadata in a local app data file
- Resolve the effective Codex auth path with this precedence:
  1. explicit in-app override
  2. `CODEX_HOME` visible to the app process
  3. `~/.codex`
- Show the effective Codex home and `auth.json` path in the UI
- Detect Codex-related running processes and block switching by default
- Allow an explicit force-switch path with clear warning copy
- Switch the active profile by validating and atomically writing the target `auth.json`
- Back up the previous auth file before overwrite when present
- Show clear status, error, and warning states
- Basic automated tests for parsing, storage, and switching logic
- Local development documentation

### MVP Out Of Scope
- Reverse-engineered ChatGPT or OAuth login flows
- Usage or quota scraping from undocumented endpoints
- Warm-up or background account validation requests
- Auto-updater
- Cross-platform support
- Web or LAN management mode
- Multi-user or account-sharing workflows
- Heavy visual polish beyond a clear usable macOS interface

## Primary Flows
### 1. Import Existing Auth File
1. User chooses an `auth.json` file or imports the current effective file.
2. App validates that the file contains a JSON object.
3. User supplies a display name and optional notes.
4. App stores the raw auth payload in Keychain and metadata in local storage.
5. Profile appears in the list and can later be edited or switched to.

### 2. Create Or Edit A Profile
1. User opens a profile detail view or creates a new profile.
2. User edits display name, notes, and raw JSON payload.
3. App validates JSON structure before save.
4. App stores the payload in Keychain and updates metadata timestamps.
5. The active live auth file is unchanged unless user explicitly switches.

### 3. Switch Active Profile
1. User selects a stored profile and presses Switch.
2. App resolves the effective auth target path and inspects running Codex-related processes.
3. If processes are detected, the app blocks switching and explains why.
4. User may explicitly confirm a force-switch.
5. App validates the target payload, backs up the existing live auth file, atomically replaces it, verifies the write, and updates UI state.
6. UI makes it clear that already-running Codex processes may still use old credentials until restarted.

### 4. Delete A Profile
1. User deletes a stored profile after confirmation.
2. App removes metadata and the Keychain secret.
3. If the deleted profile matched the live on-disk auth, the app leaves the live file unchanged and marks the current auth as unmanaged or external.

## Failure Modes
- Invalid or non-object JSON import payload
- Missing or inaccessible target Codex home
- Unable to create backup or write target auth file
- Target file written but verification mismatch on readback
- Keychain save or read failure
- Corrupt profile metadata store
- Running Codex processes detected during switch
- Multiple profiles match the live auth payload, making active-state attribution ambiguous
- Finder-launched app cannot see shell-only `CODEX_HOME`

## UX Requirements
- Active profile state must be obvious
- Effective auth location must always be visible
- Blocking process information must be readable and actionable
- Force-switch warning copy must clearly state restart expectations
- Errors must be specific enough for local troubleshooting
- External or unmanaged active auth state must be surfaced clearly

## Acceptance Criteria
- User can manage multiple local profiles without editing files manually
- Importing an existing `auth.json` creates a reusable stored profile
- Profile auth payloads are stored in Keychain, not plaintext metadata files
- The app shows the effective auth location and how it was resolved
- Switching creates a backup when a live auth file already exists
- Switching writes atomically and verifies the final on-disk contents
- The app blocks switching when Codex processes are running unless the user explicitly force-confirms
- The app supports create, update, duplicate, delete, import, and switch flows
- Core parsing, storage, and switching logic is covered by automated tests
- The project builds locally with Xcode and includes clear run instructions
