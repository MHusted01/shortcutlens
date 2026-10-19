# Settings

Open them from the ShortcutLens menu bar icon > Settings… (Cmd+,). Changes
apply at once and are stored locally in the app's preferences.

The window has four tabs and opens on the one you used last.

## General

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/settings-general-dark.png">
  <img src="images/settings-general-light.png" width="450" alt="The General tab of ShortcutLens Settings with the Hold Command for slider at 0.45 seconds and the Launch at login switch">
</picture>

- **Hold Command for:** how long Command must be held before the overlay
  shows, 0.1 to 1.5 s (default 1.0 s).
- **Launch at login:** start ShortcutLens when you log in. If macOS asks for
  approval, allow it in System Settings > General > Login Items.

## Overlay

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/settings-overlay-dark.png">
  <img src="images/settings-overlay-light.png" width="450" alt="The Overlay tab of ShortcutLens Settings with the Show disabled items and Show system shortcuts switches">
</picture>

- **Show disabled items:** also list commands that are greyed out in the
  app's menu right now. They are dimmed and cannot be run.
- **Show system shortcuts:** end the overlay with the System section (on by
  default). System rows are display-only.

## Packs

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/settings-packs-dark.png">
  <img src="images/settings-packs-light.png" width="450" alt="The Packs tab of ShortcutLens Settings with the number of packs in use and the Reload and Show Packs Folder buttons">
</picture>

- **Shortcut packs:** how many packs are in use, and any pack file that could
  not be loaded, with the reason. Show Packs Folder opens the folder for your
  own packs. See [packs.md](packs.md) for the format.

## Advanced

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/settings-advanced-dark.png">
  <img src="images/settings-advanced-light.png" width="450" alt="The Advanced tab of ShortcutLens Settings with the Menu depth stepper at 8">
</picture>

- **Menu depth:** how many submenu levels are read, 1 to 8 (default 8).
  Lower it if an app with very deep menus is slow to show.
