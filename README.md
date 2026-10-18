# ShortcutLens

Hold Command to see every keyboard shortcut of the app you are using.

ShortcutLens is a small, native macOS menu bar app. While you hold the
Command key, it shows an overlay with the frontmost app's menu shortcuts,
grouped by menu. Click an entry to run that command.

**Status:** v0.1.0, the first usable release (MVP). It covers:

- Holding Command shows the overlay; pressing another key, clicking or a
  system shortcut such as Cmd+Space cancels it.
- Shortcuts are read from the frontmost app's menu bar and grouped by menu.
- Clicking an entry runs that menu command.
- Onboarding walks you through granting the Accessibility permission.

Settings and favourites are planned for later releases.

## Command palette

Not released yet; it comes with v0.2.0. Double-tap Command (press and release
it twice quickly) to open the overlay as a command palette. It stays open
without holding Command:

- Type to filter the shortcuts by name; case and accents are ignored.
- Up and Down select an entry, Left and Right jump between columns, Return
  runs the selected entry.
- Escape clears the search; a second Escape closes the palette. Clicking
  outside it or switching apps closes it too.

If macOS Dictation is set to "Press Command Key Twice" (System Settings >
Keyboard > Dictation > Shortcut), both react to the double tap. Pick another
Dictation shortcut; a setting for the palette trigger is planned.

## Privacy first

No telemetry, no network access, no third-party code. See [PRIVACY.md](PRIVACY.md).

## Requirements

- macOS 14 Sonoma or later
- Accessibility permission (System Settings > Privacy & Security > Accessibility)

Accessibility is the only permission ShortcutLens needs. It is used to read
the frontmost app's menus and to notice key presses while you hold Command
(so Cmd+C does not open the overlay). Input Monitoring is not needed: the app
uses `NSEvent` monitors, not an event tap. It only notes that a key was
pressed, never which one, and checks the time since the last key press
(`CGEventSource`) to notice system shortcuts.

## Install

Download the latest `ShortcutLens-x.y.z.zip` from
[Releases](https://github.com/MHusted01/shortcutlens/releases) and verify it:

```sh
shasum -a 256 -c ShortcutLens-x.y.z.zip.sha256
```

The app is a universal binary (Apple silicon and Intel), ad-hoc signed and
not notarized. Unzip it, move it to `/Applications` and remove the
quarantine flag:

```sh
ditto -x -k ShortcutLens-x.y.z.zip .
mv ShortcutLens.app /Applications/
xattr -dr com.apple.quarantine /Applications/ShortcutLens.app
```

Without that, macOS 15 and later refuse to open the app; right-click > Open
no longer bypasses Gatekeeper there. On macOS 14 right-click > Open also works.

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
make integration  # local only: reads Fixtures/MenuFixture through the AX API
```

`make integration` runs inside ShortcutLens.app and needs its Accessibility
permission, so set up local signing (below) first. CI does not run it.

### Local signing (one-time setup)

Ad-hoc signatures change on every build, so macOS forgets the Accessibility
permission after each rebuild. Create a stable self-signed identity once:

```sh
scripts/create-dev-cert.sh   # "ShortcutLens Development" in the login keychain
make build
```

The script also writes the gitignored `Config/Local.xcconfig`, which makes
Debug builds use that identity. Then grant the Accessibility permission once;
later rebuilds keep it:

```sh
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

Click **+**, press Cmd+Shift+G, choose
`build/Build/Products/Debug/ShortcutLens.app` and switch it on. The pane is
called Accessibility on older macOS versions; newer ones name it after
device control and data access (Danish: "Styring af enhed og adgang til
data"). The command above opens it either way.
On the first build macOS may ask whether `codesign` may use the key: choose
Always Allow. CI and Release builds stay ad-hoc signed. To undo it, run
`security delete-identity -c "ShortcutLens Development"` and
`rm Config/Local.xcconfig`.

Project layout:

- `ShortcutLensCore/` - Swift package with all testable logic
- `App/` - AppKit/SwiftUI app layer
- `Fixtures/MenuFixture/` - app with known menus, read by `IntegrationTests/`
- `project.yml` - XcodeGen spec (the Xcode project is generated, not committed)

See [CONTRIBUTING.md](CONTRIBUTING.md) for the pull request workflow.

## License

[MIT](LICENSE)
