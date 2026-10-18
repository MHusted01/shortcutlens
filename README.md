# ShortcutLens

Hold Command to see every keyboard shortcut of the app you are using.

ShortcutLens is a small, native macOS menu bar app. While you hold the
Command key, it shows an overlay with the frontmost app's menu shortcuts,
grouped by menu. Click an entry to run that command.

**Status:** early development (Phase 0: project setup). Not usable yet.

## Privacy first

No telemetry, no network access, no third-party code. See [PRIVACY.md](PRIVACY.md).

## Requirements

- macOS 14 Sonoma or later
- Accessibility permission (System Settings > Privacy & Security > Accessibility)

## Install

Download the latest `ShortcutLens-x.y.z.zip` from
[Releases](https://github.com/MHusted01/shortcutlens/releases) and verify it:

```sh
shasum -a 256 -c ShortcutLens-x.y.z.zip.sha256
```

The app is ad-hoc signed, not notarized. After unzipping, remove the
quarantine flag or right-click the app and choose Open:

```sh
xattr -dr com.apple.quarantine ShortcutLens.app
```

Because the signature changes with every release, macOS asks for the
Accessibility permission again after each update. Remove the old entry in
System Settings and add the new app.

## Development

Requirements: Xcode 16 or later, plus `brew install xcodegen swiftlint swiftformat`.

```sh
make generate   # create ShortcutLens.xcodeproj from project.yml
make test       # Core unit tests with an 80% line coverage gate
make lint       # SwiftLint and SwiftFormat
make check      # no-telemetry check
make build      # Debug build of the app
```

Project layout:

- `ShortcutLensCore/` - Swift package with all testable logic
- `App/` - AppKit/SwiftUI app layer
- `project.yml` - XcodeGen spec (the Xcode project is generated, not committed)

See [CONTRIBUTING.md](CONTRIBUTING.md) for the pull request workflow.

## License

[MIT](LICENSE)
