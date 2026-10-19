# ShortcutLens

Hold Command to see every keyboard shortcut of the app you are using.

ShortcutLens is a small, native macOS menu bar app. While you hold the
Command key, it shows an overlay with the frontmost app's menu shortcuts,
grouped by menu. Click an entry to run that command.

**Status:** v0.4.0. It covers:

- Holding Command shows the overlay; pressing another key, clicking or a
  system shortcut such as Cmd+Space cancels it.
- Shortcuts are read from the frontmost app's menu bar and grouped by menu.
- Clicking an entry runs that menu command.
- Double-tapping Command opens a searchable command palette (below).
- A System section lists the macOS shortcuts you have turned on in System
  Settings > Keyboard > Keyboard Shortcuts, such as Spotlight and screenshots.
  Their keys are labelled for your current keyboard layout.
- App Shortcuts you defined yourself (System Settings > Keyboard > Keyboard
  Shortcuts > App Shortcuts) are marked with a person icon. In sandboxed
  apps such as TextEdit, Safari and Preview, only shortcuts set for "All
  Applications" are marked: macOS keeps their per-app settings in the app's
  own data and does not let ShortcutLens read or edit them.
- Conflicts are marked: when two entries use the same keys, both rows say
  which other entry also uses them ("Also used by System > ..."), within the
  app or against a system shortcut.
- Shortcut packs add shortcuts that an app has but does not show in its
  menus, from local JSON files. See [docs/packs.md](docs/packs.md).
- Right-click a menu entry to change its shortcut (below) or add it to
  your favourites. Favourites appear in a Favourites section at the top of
  the overlay and are starred where they are in the app's menus.
- Export to Markdown or PDF, and a practice mode that quizzes you on an
  app's shortcuts (both below).
- A settings window for the trigger delay, menu depth, disabled items, system
  shortcuts, shortcut packs and launch at login.
- Onboarding walks you through granting the Accessibility permission.

Favourites and practice progress are matched by menu titles, which macOS
translates. They only match in the system language they were made in.

## Command palette

Double-tap Command (press and release it twice quickly) to open the overlay
as a command palette. It stays open without holding Command:

- Type to filter the shortcuts by name; case and accents are ignored.
- Up and Down select an entry, Left and Right jump between columns, Return
  runs the selected entry.
- Escape clears the search; a second Escape closes the palette. Clicking
  outside it or switching apps closes it too.

If macOS Dictation is set to "Press Command Key Twice" (System Settings >
Keyboard > Dictation > Shortcut), both react to the double tap. Pick another
Dictation shortcut; a setting for the palette trigger is planned.

## Export

Choose Export Shortcuts as Markdown… or Print Shortcuts… from the
ShortcutLens menu bar icon to export the frontmost app's shortcuts. The
export has every section the overlay shows, without a search filter, and
marks App Shortcuts and conflicts. To get a PDF, choose Save as PDF in the
print panel. Files are only written where you save them. Headings and the
file name are in the app's language, like the menu titles from the app.

## Editing shortcuts

Right-click a menu entry and choose Edit Shortcut… (most reliable in the
command palette). Press the new keys, then Save. Character keys need
Command, Option or Control; named keys such as arrows, Return or Tab work
too, and F1 to F19 may be used alone or with Shift. If the keys are already
used in the app or by a system shortcut, you are warned and can choose Save
Anyway. Remove Custom Shortcut restores the menu's own shortcut.

The change is stored as an App Shortcut in the app's own preferences, the
same place System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts
uses; "All Applications" entries are never changed. The app reads it at
launch, so ShortcutLens offers to relaunch it (the app asks about unsaved
documents as usual). Notes:

- Shortcuts that macOS itself uses never reach the editor and cannot be
  recorded.
- Sandboxed apps such as TextEdit, Safari and Preview cannot be edited; use
  System Settings for them.

## Practice

Choose Practice Shortcuts… from the ShortcutLens menu bar icon to be quizzed
on the shortcuts of the app that was in front. Each round asks up to 10
menu shortcuts: press the keys, or choose Show Answer. Shortcuts you miss
and new ones come first, then ones you know less well; favourites come first
among equals. Progress is saved per app and stays on your Mac; Reset Progress
starts over. Shortcut packs and system shortcuts are not asked.

## Settings

Open them from the ShortcutLens menu bar icon > Settings… (Cmd+,). Changes
apply at once and are stored locally in the app's preferences.

- **Hold Command for:** how long Command must be held before the overlay
  shows, 0.1 to 1.5 s (default 1.0 s).
- **Menu depth:** how many submenu levels are read, 1 to 8 (default 8).
  Lower it if an app with very deep menus is slow to show.
- **Show disabled items:** also list commands that are greyed out in the
  app's menu right now. They are dimmed and cannot be run.
- **Show system shortcuts:** end the overlay with the System section (on by
  default). System rows are display-only.
- **Shortcut packs:** how many packs are in use, and any pack file that could
  not be loaded, with the reason. Show Packs Folder opens the folder for your
  own packs. See [docs/packs.md](docs/packs.md) for the format.
- **Launch at login:** start ShortcutLens when you log in. If macOS asks for
  approval, allow it in System Settings > General > Login Items.

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

Requirements: Xcode 26 or later, plus `brew install xcodegen swiftlint swiftformat`.

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
