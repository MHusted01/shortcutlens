# The overlay

Hold Command to show an overlay with the frontmost app's menu shortcuts,
grouped by menu. Pressing another key, clicking or a system shortcut such as
Cmd+Space cancels it. Click an entry to run that menu command. To keep it open
without holding Command, double-tap Command for the
[command palette](palette.md).

## What it shows

- Shortcuts are read from the frontmost app's menu bar and grouped by menu.
  Entries that share a name show their menu path, such as
  `Find > Find Next` next to `Spelling > Find Next`.
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
  menus, from local JSON files. See [packs.md](packs.md).
- Keys are labelled for your current keyboard layout and update when you
  switch layouts. Arrow keys are drawn the way the macOS menus draw them.

## Favourites

Right-click a menu entry to add it to your favourites, or to
[change its shortcut](editing.md). Favourites appear in a Favourites section
at the top of the overlay and are starred where they are in the app's menus.

Favourites and practice progress are matched by menu titles, which macOS
translates. They only match in the system language they were made in.

## Languages

ShortcutLens is in English and Danish, following your system language. See
[CONTRIBUTING.md](../CONTRIBUTING.md#translations) to add a language.

## VoiceOver

Use the [command palette](palette.md). It announces the app, the number of
matches and the selected entry, reads keys as words ("Command Shift S") and
lists section headings in the rotor.
