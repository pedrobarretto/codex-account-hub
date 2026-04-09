# Contributing

Thanks for contributing to Codex Account Hub.

## Before You Start

- Open an issue before large changes so scope and direction are clear.
- Keep changes focused. Small pull requests are easier to review and merge.
- Do not include real credentials, `auth.json` payloads, certificates, or private keys in issues, pull requests, screenshots, or test fixtures.

## Development Notes

- App target: `CodexAccountHub`
- Core package: `Packages/CodexAuthCore`
- Tests:
  - `swift test` in `Packages/CodexAuthCore`
  - `xcodebuild -project CodexAccountHub.xcodeproj -scheme CodexAccountHub -destination "platform=macOS" test`

## Pull Requests

- Describe the user-visible behavior change clearly.
- Mention any security or data-handling implications.
- Add or update tests when behavior changes.
- Keep release workflow changes narrowly scoped and explain why they are needed.

## Security

If you find a security issue, follow the guidance in `SECURITY.md` instead of opening a public issue.

## Release Credentials

This repository uses GitHub Actions secrets for release signing and notarization. Contributors should not add certificates, API keys, `.env` files, or local Apple credential files to the repository.
