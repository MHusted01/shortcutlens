# Editing shortcuts

Right-click a menu entry and choose Edit Shortcut… (most reliable in the
[command palette](palette.md)). Press the new keys, then Save. Character keys
need Command, Option or Control; named keys such as arrows, Return or Tab work
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
