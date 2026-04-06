# Codex Account Hub Execution Plan

## Milestone 1: Spec Set
Completion criteria:
- `product-spec.md`, `technical-design.md`, `execution-plan.md`, `decisions-log.md`, and `progress-log.md` exist
- product scope, failure modes, architecture, and test strategy are documented
- initial decisions are captured

Tasks:
- document product problem and flows
- document technical architecture and storage model
- document milestone breakdown
- log initial decisions and assumptions
- create a progress log entry for kickoff

## Milestone 2: Core Package
Completion criteria:
- `Packages/CodexAuthCore` builds
- core auth, storage, path resolution, process inspection, and switch coordination logic are implemented
- package tests cover the critical switching and parsing paths

Tasks:
- scaffold the Swift package manifest
- implement `AuthPayload`
- implement `AuthPathResolver`
- implement metadata store and models
- implement Keychain wrapper
- implement process inspector
- implement switch coordinator and backup logic
- add package tests

## Milestone 3: macOS App Shell
Completion criteria:
- native SwiftUI app project exists and builds
- app can load profiles, edit them, import payloads, and switch profiles through the core package

Tasks:
- create the macOS app target and project
- wire package dependency into the app
- implement `AppModel`
- build sidebar/detail UI
- add import, save, duplicate, delete, and switch flows
- add process warning and delete confirmation dialogs
- add settings UI for Codex home override

## Milestone 4: Safety And Persistence Pass
Completion criteria:
- live auth path is shown in UI
- active profile detection works
- backups are created on switch
- switching error states are surfaced clearly

Tasks:
- wire real application support paths
- wire real Keychain persistence
- implement active-profile matching against live auth
- refine force-switch warning UX
- tighten validation and status copy

## Milestone 5: Verification And Docs
Completion criteria:
- automated tests run successfully
- app project builds locally
- README explains setup, run, and limitations
- progress log and decision log are current

Tasks:
- run package tests
- run project build/tests
- write README
- update progress and decisions docs with final notes
