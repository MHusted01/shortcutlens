# Architecture

How the code is organised, how the main features flow through it, and where
new code goes. The area table also gives the folder each source file lives
in.

## Two layers

| Layer | What it holds | Imports | Tests |
| --- | --- | --- | --- |
| `ShortcutLensCore/` | Models, formatting, the menu walk, state machines, layout maths, parsers | `Foundation` and `CoreGraphics` only | `make test`, 80% line coverage gate |
| `App/` | Accessibility calls, event monitors, preferences reads and writes, windows, panels, SwiftUI views | `AppKit`, `SwiftUI` and other system frameworks, plus `ShortcutLensCore` | Manual checks; `make integration` for the AX read |

The rule for new code: if it can be tested without a running app, it goes
in Core and is written test-first. Core never touches the system. It reaches
the Accessibility API through the `AXClient` / `AXActionClient` protocols,
and `UserDefaults` through `SettingsStore`. Tests use `FakeAXClient` and an
in-memory store for these. App code stays thin: it collects input from the
system, hands it to a Core type, and applies the result.

Core types are values (`struct`, `enum`). A change returns a new copy
(`updated(with:)`, `with(query:)`, `pinning(_:)`), and the App controllers
keep the current value. Long-lived objects with identity (controllers,
panels, windows) exist only in App and run on the main actor. Work that can
block, such as menu reads, `AXPress` and preferences synchronizing, runs in
detached tasks.

`Fixtures/MenuFixture/` is an app with known menus. `IntegrationTests/`
reads it through the real AX API (`make integration`, local only).

## Main flows

### Hold Command: overlay

1. `TriggerController` installs global and local `NSEvent` monitors once
   `PermissionController` reports the Accessibility permission. Each
   modifier, key or click event goes to `TriggerStateMachine`, with
   `HeldModifiers` as the input.
2. Command pressed alone starts a countdown (`startTimer`), and
   `TriggerController.onArm` calls `OverlayController.prepare()`. Any other
   key, modifier, click or app switch cancels it. `MissedKeyDown` catches
   system hotkeys that the monitors never see.
3. `prepare()` asks `OverlayContentLoader` for the app. It returns the
   cached content from `MenuCache` at once, then starts
   `AppContentReader.read` in a detached task, or reuses the read already
   running for that app:
   - `MenuReader` walks the menu bar through `DeadlineAXClient`, which wraps
     `SystemAXClient` with a 3 second budget. Each item becomes a
     `MenuShortcut` (`ModifierMask`, `MenuGlyph`) in a `MenuGroup`.
   - `UserKeyEquivalentSource` reads the App Shortcuts (`UserKeyEquivalents`),
     `PackSource` reads the shortcut packs (`PackLibrary`), and
     `SystemHotKeySource` reads the system shortcuts (`SystemHotKeyCatalog`),
     labelled with a `KeyboardLayout` snapshot.
   - `OverlayContent` turns the groups into sections of rows, with keys
     formatted by `ShortcutFormatter`. It then appends the pack sections,
     disambiguates titles (`+Paths`) and marks conflicts (`+Conflicts`,
     `ShortcutConflicts`).
4. When the read finishes, `MenuReadTracker` decides whether it is still
   current (same settings and keyboard layout) and for the latest
   `prepare()`. The loader stores a current read in `MenuCache`
   (`MenuCache+Read`), appends the System section and hands it to the
   controller, which pins the Favourites section first with `pinning(_:)`
   (`OverlayContent+Favourites`, `Favourites`). A read that finishes during
   the countdown lays the panel out ahead of time (`render(prepareOnly:)`).
5. When the timer fires, `onShow` calls `show()`, which calls `render()`.
   `OverlayLayout` picks the body, `PanelLayout` and `ColumnLayout`
   choose the columns and size, and `ScreenPicker` picks the screen under
   the pointer. `OverlayPanel` shows `OverlayView` without activating
   ShortcutLens.
6. A click on a row calls `run(_:)` (`OverlayController+Run.swift`). The
   panel hides and `MenuItemRunner` presses the item through
   `SystemAXClient` (`AXPress`) in a detached task. The controller beeps if
   the item was not run. Releasing Command calls `onHide`.

### Double tap: palette

1. `TriggerController` passes the same events to `DoubleTapDetector`, set
   to the `PaletteTrigger` from settings. A double tap goes to
   `TriggerStateMachine` as `.doubleTap`, which answers `showPalette`.
2. `OverlayController.showPalette()` hands the current content to
   `PaletteController`, which wraps it in `PaletteState` and presents the
   panel as key. The header shows
   `SearchBox` / `SearchField`, and `PaletteModel` (in `OverlayView.swift`)
   carries the query, selection and body.
3. Typing calls `PaletteState.with(query:)`, which filters with
   `ShortcutMatcher`. Arrow keys, Return and Escape come in as
   `SearchCommand`s, and `PaletteState+Commands` answers each one: move the
   selection (across columns with `PaletteState+Columns`), run the row like
   a click, beep, or close. `PaletteController` announces each change with
   `PaletteAnnouncement` and `SpokenKeys`.
4. Every way of closing the palette goes through `onClosePalette`, which
   becomes `TriggerController.closePalette()`, so the state machine always
   knows.

### Shortcut editing

1. "Edit Shortcut…" in a row's context menu calls
   `OverlayController.edit(_:id:)` (`+Edit`). It hides the panel and passes
   a `ShortcutEditRequest`, holding the row and the shown content, to
   `ShortcutEditor.show(_:)`.
2. `ShortcutEditorView` records keys with `KeyRecorder` (`RecordedKeys`).
   `ShortcutRecording` rejects keys that cannot be saved, and
   `OverlayContent.clashes(with:excludingSection:row:)` (`+Edit`) lists the
   rows that already use them. `AppSandbox` explains why sandboxed apps
   cannot be edited.
3. Save builds a `UserKeyEquivalent` (`+Store`), and
   `UserKeyEquivalentWriter` writes it into the app's own preferences
   domain. `AppRelauncher` can quit and reopen the app so it reads the
   change.

### Shortcut packs

`PackSource` reads JSON files from the user's packs folder and the bundled
`App/Resources/Packs`. `ShortcutPackParser` (with `PackKeys` for key names)
turns each file into a `ShortcutPack` or a `PackError`. `PackLibrary`
decides which packs apply to which app, and `sections(for:)` gives the
`PackSection`s that the menu read appends. `SettingsController` reloads the
library for `PackSettings`, the Packs tab that lists files that failed to
load.

### Practice

The menu bar item calls `PracticeController.start()` for the
`FrontmostApp`. It runs `AppContentReader.read` with system
shortcuts on. `PracticeDeck` builds `PracticeCard`s and picks the
questions, weakest first, using `PracticeProgress` (Leitner boxes in
`UserDefaults`) and favourites. `PracticeView` takes each answer with
`KeyRecorder`, and `PracticePress` checks it against the card.
`PracticeSession` holds the round, and progress is saved after every
answer.

### Export

The menu bar items call `CheatSheetExporter`. It runs the same
`AppContentReader.read` for the `FrontmostApp`, without the
overlay's favourites, and appends the System section. `CheatSheetMarkdown`
renders the Markdown file written through a save panel. `CheatSheetDocument`
lays out the printed sheet, with `CheatSheetLayout` for the keys column.

### Settings and onboarding

`SettingsController` loads `AppSettings` from `UserDefaults`, and every
change calls `onChange`. `AppDelegate.apply(_:)` then passes the settings to
the trigger, overlay, exporter and practice. `SettingsTabController` hosts
one `SettingsView` per `SettingsTab`. `PermissionController` polls
`AXIsProcessTrusted`, and `AccessibilityPermission` decides when
`OnboardingView` opens (`OnboardingStep`, `OnboardingText`). The result
turns the trigger's monitors on or off.

`ShortcutLensApp.swift` holds the menu bar menu and `AppDelegate`, which
creates every controller and wires their callbacks together.

## Areas

Every source file belongs to exactly one area, and each area is a folder:
`ShortcutLensCore/Sources/ShortcutLensCore/<Area>/` in Core, and
`App/Sources/<Area>/` in the app. XcodeGen and SwiftPM
pick up subfolders, so a new area needs no build settings.

Core tests mirror the source folders: the tests for `Menu/MenuReader.swift`
are in `ShortcutLensCoreTests/Menu/MenuReaderTests.swift`. A few files serve
every area and stay at the top of the test target:

- `FakeAXClient`: the in-memory `AXClient` for menu reads and presses.
- `RepositoryFiles`: finds files in the checkout that tests read, such as
  the string catalogs, `PRIVACY.md` and the bundled packs.
- `LocalizationTests`: checks both string catalogs against all sources.
- `Fixtures/`: files loaded through `Bundle.module`.

`Localizable.xcstrings` stays at the top of the Core sources.

| Area | Core | App |
| --- | --- | --- |
| Menu | `AXClient`, `DeadlineAXClient`, `MenuReader`, `MenuGroup`, `MenuShortcut`, `MenuGlyph`, `ModifierMask`, `MenuItemRunner`, `MenuCache`, `MenuCache+Read`, `MenuReadTracker` | `SystemAXClient`, `AppContentReader`, `UncheckedSendable` |
| Keys | `KeyCombo`, `KeyDisplay`, `KeyLabels`, `KeyCodes`, `NamedKeys`, `ShortcutFormatter`, `SpokenKeys`, `ShortcutConflicts`, `SymbolicHotKey`, `SystemHotKeyCatalog`, `UserKeyEquivalent`, `UserKeyEquivalent+Store`, `UserKeyEquivalents` | `KeyboardLayout`, `SystemHotKeySource`, `UserKeyEquivalentSource` |
| Trigger | `TriggerStateMachine`, `HeldModifiers`, `DoubleTapDetector`, `PaletteTrigger`, `MissedKeyDown` | `TriggerController` |
| Overlay | `OverlayContent`, `OverlayContent+Paths`, `OverlayContent+Conflicts`, `OverlayContent+Favourites`, `Favourites`, `PanelLayout`, `ColumnLayout`, `ScreenPicker` | `OverlayController`, `OverlayController+Run`, `+Favourites`, `+Edit`, `OverlayContentLoader`, `OverlayLayout`, `OverlayLog`, `OverlayPanel`, `OverlayView`, `OverlayBackground` |
| Palette | `PaletteState`, `PaletteState+Columns`, `PaletteState+Commands`, `SearchCommand`, `ShortcutMatcher`, `PaletteAnnouncement` | `PaletteController`, `SearchBox`, `SearchField` |
| Editing | `ShortcutRecording`, `OverlayContent+Edit` | `ShortcutEditor`, `ShortcutEditorView`, `KeyRecorder`, `UserKeyEquivalentWriter`, `AppRelauncher`, `AppSandbox` |
| Packs | `ShortcutPack`, `ShortcutPackParser`, `PackKeys`, `PackLibrary` | `PackSource`, `PackSettings` |
| Practice | `PracticeDeck`, `PracticePress`, `PracticeProgress`, `PracticeSession` | `PracticeController`, `PracticeView` |
| Export | `CheatSheetMarkdown`, `CheatSheetLayout` | `CheatSheetExporter`, `CheatSheetDocument` |
| Settings | `AppSettings`, `SettingsTab`, `AppVersion` | `SettingsController`, `SettingsTabController`, `SettingsView`, `ShortcutLensApp`, `FrontmostApp` |
| Onboarding | `AccessibilityPermission`, `OnboardingStep`, `OnboardingText` | `PermissionController`, `OnboardingView` |

Notes on the less obvious choices:

- Keys holds everything about which keys a shortcut uses and how they are
  shown, including the two preference stores behind them: system shortcuts
  (`SymbolicHotKey`) and App Shortcuts (`UserKeyEquivalent`). Editing only
  writes App Shortcuts.
- `KeyRecorder` is in Editing, its first user. Practice reuses it.
- `ShortcutLensApp` (menu bar menu and `AppDelegate`), `FrontmostApp` and
  `AppVersion` are app-wide. They sit in Settings because the menu bar is
  the app's own settings surface. Do not add a catch-all folder for them.
- `AppContentReader` is in Menu, not Overlay, because Practice and Export
  read through it too.
- `OverlayController` keeps `+Run`, `+Favourites` and `+Edit` as extension
  files: each is one action on the controller's state, with no state of its
  own (see Naming).
- Core keeps its extension files for the same reason: each returns a copy
  or answers a question from the type's own state. `OverlayContent` has
  `+Paths`, `+Conflicts`, `+Favourites` and `+Edit` (the conflict rules
  themselves live in `ShortcutConflicts`); `PaletteState` has `+Columns`
  and `+Commands` (`CommandResponse` is a return value, not stored state);
  `MenuCache` has `+Read` and `UserKeyEquivalent` has `+Store`.

## Naming

- A file is named after the one type it declares (`MenuReader.swift`). Small
  helper types that only serve that type may share its file
  (`OverlaySection` and `OverlayRow` live in `OverlayContent.swift`).
- `Type+Topic.swift` holds an extension that adds one topic to an existing
  type, such as `OverlayContent+Paths.swift` or `OverlayController+Run.swift`.
  The extension goes in the area of the feature it serves, even when the
  type lives elsewhere (`OverlayContent+Edit` is in Editing).
- Use an extension file when the topic works on the type's existing state
  and has no state of its own: Core transformations that return a copy, or
  one action of an App controller.
- Use a new type when the topic needs its own stored state, its own
  lifecycle, or more than one caller, or when an extension would only exist
  to keep a file under the 400 line limit. For example, `PaletteState` is a
  type, not an `OverlayContent` extension, because it keeps the query and
  selection.
- Core types that wrap the system are named after what they model
  (`MenuReader`, `AXClient`). Their App counterparts say where the data
  comes from: `System*` for the AX implementation (`SystemAXClient`), and
  `*Source` / `*Writer` for preferences and files.
