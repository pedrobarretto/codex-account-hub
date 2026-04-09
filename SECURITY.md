# Security Policy

## Supported Versions

This project is maintained on the `main` branch. Security fixes are applied to the latest code on `main` and included in the next tagged release.

## Reporting a Vulnerability

Please do not open a public GitHub issue for suspected security vulnerabilities.

Instead, report the issue privately to the maintainer through GitHub security reporting if it is enabled for the repository. If that option is unavailable, contact the maintainer directly and include:

- a short description of the issue
- affected version or commit
- reproduction steps or proof of concept
- impact assessment
- any suggested mitigation

I will acknowledge receipt as soon as practical, investigate the report, and coordinate disclosure once a fix or mitigation is available.

## Scope Notes

Codex Account Hub is a local macOS utility that manages local authentication profile files. Reports are especially helpful for issues involving:

- unintended disclosure of auth material
- unsafe file replacement behavior
- privilege or sandbox escape concerns
- improper storage or retrieval of secrets
- release signing or notarization integrity problems
