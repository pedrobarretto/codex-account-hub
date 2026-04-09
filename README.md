# Codex Account Hub

<img src="CodexAccountHub/Assets.xcassets/AppIcon.appiconset/appicon-256.png" alt="Codex Account Hub icon" width="96" />

Codex Account Hub is a macOS menu bar app for managing multiple local Codex account profiles and switching which one is active.

## Overview

Codex uses a local `auth.json` file for authentication. This project exists to make that manageable when you need more than one account or profile on the same machine.

Instead of manually replacing files, Codex Account Hub lets you keep named profiles locally, choose the one you want active, and safely update the live auth file used by Codex CLI and the Codex desktop app.

## Core Behavior

- stores multiple local Codex auth profiles
- imports an existing `auth.json`
- lets you create, edit, duplicate, and delete profiles
- switches the live Codex auth file to the selected profile
- backs up the previous auth file before replacing it
- detects running Codex processes before switching and blocks unsafe changes by default

## How It Works

- auth payloads are stored locally in macOS Keychain
- profile metadata is stored locally in Application Support
- the app resolves the live auth location from an explicit app override, `CODEX_HOME`, or `~/.codex`
- profile switching writes the selected payload atomically to the live auth location

## Project Structure

- `CodexAccountHub/`: macOS SwiftUI app
- `Packages/CodexAuthCore/`: core profile, storage, path resolution, and switching logic
- `CodexAccountHubTests/`: app-level smoke tests
- `docs/specs/`: product and technical notes for development

## Scope

This project is a local utility for people who work with multiple Codex accounts on the same Mac. It is focused on safe profile storage and predictable account switching, not on cloud sync, account provisioning, or remote credential management.

## Support

If Codex Account Hub is useful to you, you can support the project here:

[Buy Me a Coffee](https://buymeacoffee.com/pedrobarretto)
