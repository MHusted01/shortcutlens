# Contributing

## Workflow

`main` is protected. Every change goes through a pull request:

1. Branch from `main`: `feat/<topic>`, `fix/<topic>`, `docs/<topic>`, `ci/<topic>`.
2. Keep the PR to one feature or fix.
3. Title the PR as a conventional commit, e.g. `feat: add overlay panel`.
   The title becomes the squash commit on `main`.
4. These checks must pass: `lint`, `test`, `build`, `no-telemetry` and
   `pr-title`.
5. The `claude-review` workflow reviews every push to the PR. Address every
   comment and resolve all conversations before merging.
6. Merge with **Squash and merge**. The branch is deleted automatically.

## Rules

- No telemetry, network code or third-party runtime dependencies (see PRIVACY.md).
- Core logic lives in `ShortcutLensCore` and is developed test-first.
  Line coverage must stay at or above 80%.
- Code must pass `make lint` (SwiftLint and SwiftFormat).

## Releases

Maintainers tag a commit on `main` with `vX.Y.Z`. The release workflow builds,
ad-hoc signs and zips the app and publishes it with a SHA-256 checksum.
