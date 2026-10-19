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

## Translations

ShortcutLens is in English and Danish, and macOS picks the language from the
system preferences. New languages are welcome. Each one needs only
translations, no code:

1. Claim your language in a comment on
   [#77](https://github.com/MHusted01/shortcutlens/issues/77), so two
   people don't do the same one.
2. Add it to both string catalogs and translate every entry:
   `App/Resources/Localizable.xcstrings` and
   `ShortcutLensCore/Sources/ShortcutLensCore/Localizable.xcstrings`.
3. Use the names macOS uses in your language, keep placeholders such as
   `%@` and `%lld`, and fill in every plural form.
4. Run `make test`: `LocalizationTests` fails when an entry is missing or a
   placeholder changed.
5. Open one PR per language, titled `feat: <Language> localization`.

[#77](https://github.com/MHusted01/shortcutlens/issues/77) has the details.

## Releases

Changes go under `## [Unreleased]` in `CHANGELOG.md`. Before a release, that
section is renamed to `## [X.Y.Z] - YYYY-MM-DD` in a PR. Maintainers then tag
the merged commit on `main` with `vX.Y.Z`. The release workflow builds, ad-hoc
signs and zips the app and publishes it with a SHA-256 checksum, using the
version's `CHANGELOG.md` section as the release notes. A tag without a
matching section fails before the build.
