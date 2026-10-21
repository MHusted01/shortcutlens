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

## Make targets

| Target | What it does | Used by |
| --- | --- | --- |
| `generate` | Creates `ShortcutLens.xcodeproj` from `project.yml` | the other targets |
| `build` | Debug build of the app | CI `build` |
| `test` | Core unit tests with an 80% line coverage gate | CI `test` |
| `lint` | SwiftLint and SwiftFormat | CI `lint` |
| `check` | No-telemetry check (`scripts/check-no-telemetry.sh`) | CI `no-telemetry` |
| `release` | Release build, zip and SHA-256 in `dist/` (`VERSION=X.Y.Z`) | `release.yml` |
| `integration` | Reads `Fixtures/MenuFixture` through the AX API | local only |
| `clean` | Removes `build/`, `dist/` and the generated project | local only |

`make integration` runs inside ShortcutLens.app and needs its Accessibility
permission, so set up local signing first (README, "Local signing"). CI
cannot grant that permission, so it does not run this test. Run it after
changes to the menu reader or the AX layer.

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

## Icons

The app icon is original artwork: a magnifying glass with the Command symbol
in the lens, chosen in
[#85](https://github.com/MHusted01/shortcutlens/issues/85).

| Path | What |
| --- | --- |
| `App/Resources/AppIcon.icon/` | The icon the app ships. Icon Composer format: `icon.json` plus one SVG per layer in `Assets/`. |
| `docs/images/icon.svg` | Flat master on the classic 1024 grid (824 pt rounded square), used in the README and anywhere outside the app. |
| `App/Resources/MenuBarIcon.xcassets/` | The menu bar icon: two 18 x 18 pt SVGs (`MenuBarIcon.svg` for 2x, `MenuBarIcon-1x.svg` for 1x), marked as a template image. |

### App icon

`AppIcon.icon` has a system gradient fill (`automatic-gradient`, blue) and two
groups, front to back:

1. `command.svg` - the Command symbol, opaque.
2. `lens.svg` and `handle.svg` - the glass and the handle, slightly
   translucent so Liquid Glass shows through.

Layers are drawn on the full 1024 x 1024 canvas; the system applies the mask,
so they do not include the rounded square or a background.

`project.yml` adds `AppIcon.icon` to the app's resources and sets
`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. On build, `actool` compiles it
into `Assets.car` (Liquid Glass, light, dark and tinted appearances on
macOS 26+) and an `AppIcon.icns` fallback for macOS 14-15. No exported PNGs
are committed.

To change it:

- Edit the layer SVGs in `App/Resources/AppIcon.icon/Assets/` and
  `icon.json`, or open `AppIcon.icon` in Icon Composer
  (`Xcode.app/Contents/Applications/Icon Composer.app`) to tune glass,
  shadow and the dark and tinted variants.
- Keep `docs/images/icon.svg` in step with the layers.
- Check the result in a build: `make build`, then look at the app in Finder
  and in the About box (menu bar icon > About ShortcutLens), in light and dark
  mode.

Preview a layer or the master without Xcode:

```sh
rsvg-convert -w 512 docs/images/icon.svg -o /tmp/icon.png
```

### Menu bar icon

`MenuBarIcon.svg` is the lens, handle and Command symbol from the master in
one colour (black on transparent; macOS ignores the colour of a template
image and tints it for light, dark and tinted menu bars). The strokes are
thicker than a straight scale-down so the Command symbol stays readable at 2x.
At 1x even that blurs, so `MenuBarIcon-1x.svg` draws a 7 x 7 px Command
symbol on the pixel grid (`shape-rendering="crispEdges"` rects). Change both
files together. The lens alone would look like Spotlight, so keep the symbol.
The app swaps the icon for the `exclamationmark.triangle` symbol while the
Accessibility permission is missing.

## Releases

Changes go under `## [Unreleased]` in `CHANGELOG.md`. Before a release, that
section is renamed to `## [X.Y.Z] - YYYY-MM-DD` in a PR. Maintainers then tag
the merged commit on `main` with `vX.Y.Z`. The release workflow builds, ad-hoc
signs and zips the app and publishes it with a SHA-256 checksum, using the
version's `CHANGELOG.md` section as the release notes. A tag without a
matching section fails before the build, so pre-release tags such as
`v1.2.0-rc1` are not supported.

Once the release is published, bump the Homebrew cask in
[MHusted01/homebrew-tap](https://github.com/MHusted01/homebrew-tap):

```sh
brew bump-cask-pr --version X.Y.Z mhusted01/tap/shortcutlens
```

It downloads the release zip, updates `version` and `sha256`, and opens a pull
request in the tap.
