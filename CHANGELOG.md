# Changelog

All notable changes to ShortcutLens are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- The "Also used by" line under a conflicting shortcut names at most three
  other entries and counts the rest, and shortens long titles. Before, every
  entry on the same keys was listed, which made the line unreadable and slow
  to build when many shortcuts shared keys ([#156](https://github.com/MHusted01/shortcutlens/issues/156)).

## [1.4.0] - 2026-10-20

### Added

- Install with Homebrew: `brew install --cask mhusted01/tap/shortcutlens`
  from the personal tap (#102).
- [Install and update guide](https://github.com/MHusted01/shortcutlens/blob/main/docs/install.md):
  checksum, first launch past Gatekeeper, granting Accessibility, updating
  and uninstalling. Release notes link to it (#103).

## [1.3.0] - 2026-10-20

### Added

- Settings > General > Open palette: open the command palette by
  double-tapping Command, Option or Control, or turn it off, so it does not
  clash with Dictation's "Press Command Key Twice" (#97).

### Changed

- The overlay appears faster in apps with large menus: it is laid out while
  Command is held, so it shows in 11-38 ms instead of 100-200 ms (Xcode:
  12 ms instead of 199 ms) (#100).

### Fixed

- Arrow keys show as `◀▶▲▼` on macOS 14, 15 and 26 too, as their menus draw
  them; before, only macOS 27 matched the menus (#99).
- The last onboarding step's button is no longer cut off in Danish. It now
  reads "Open System Settings", like the text above it, and footer buttons
  always show their full title (#123).

## [1.2.0] - 2026-10-20

This release polishes the overlay, palette, settings and onboarding. The
visual changes follow the
[UI spec on #90](https://github.com/MHusted01/shortcutlens/issues/90#issuecomment-6277410728).
Screenshots are from macOS 26.

<img src="https://raw.githubusercontent.com/MHusted01/shortcutlens/v1.2.0/docs/images/overlay-light.png" alt="Overlay in light mode" width="420"> <img src="https://raw.githubusercontent.com/MHusted01/shortcutlens/v1.2.0/docs/images/overlay-dark.png" alt="Overlay in dark mode" width="420">

<img src="https://raw.githubusercontent.com/MHusted01/shortcutlens/v1.2.0/docs/images/palette-dark.png" alt="Command palette with a query and a selection" width="420"> <img src="https://raw.githubusercontent.com/MHusted01/shortcutlens/v1.2.0/docs/images/settings-general-light.png" alt="Settings, General tab" width="420">

### Added

- The README shows a demo GIF, and the overlay, palette, settings and FAQ
  pages have light and dark screenshots. The social preview shows the
  overlay. (#95)

### Changed

- The overlay uses Liquid Glass on macOS 26 and later and a light or dark
  material on macOS 14-15 that follows the system appearance. It fades in and
  out, and with Reduce Motion it only fades. Row highlights, section spacing
  and marker colours follow the new visual spec. (#91)
- The command palette's search field sits in a rounded container with a
  magnifying glass and an accent focus outline, thicker under Increase
  Contrast. When nothing matches, the palette shows a "No matching
  shortcuts" state, which VoiceOver announces. (#92)
- Settings has toolbar tabs: General, Overlay, Packs and Advanced. The window
  fits each tab and opens on the tab you used last. (#93)
- Onboarding has three steps: what the app does, how to use it, and the
  Accessibility permission. When the permission is granted, the last step
  shows that ShortcutLens is ready and stays open until you close it. "Welcome to ShortcutLens…"
  in the menu bar menu opens it again. (#94)

## [1.1.0] - 2026-10-19

### Added

- App icon: a magnifying glass with the Command symbol, with Liquid Glass,
  dark and tinted variants on macOS 26 and a fallback for macOS 14-15. The
  menu has an "About ShortcutLens" item. (#106)
- Menu bar icon drawn from the app icon, with a pixel-grid version for 1x
  displays. (#107)
- Issue forms for bugs, feature requests and translations, a code of conduct
  and this changelog. (#87)
- FAQ and troubleshooting page, and a page for each feature in `docs/`. (#88)

### Changed

- The README starts with the icon, badges and install steps and keeps the
  feature details in `docs/`. (#88)

## [1.0.0] - 2026-10-19

### Added

- VoiceOver support: the command palette announces the app, the number of
  matches and the selected entry, reads keys as words and lists section
  headings in the rotor. (#74)
- English and Danish, following the system language, and a guide to adding a
  translation. (#75, #78)
- Entries that share a name show their menu path, such as
  `Find > Find Next`. (#79)

### Changed

- Key labels update when you switch keyboard layouts. (#73)
- Space and Help keys are labelled in the system language. (#81)
- Arrow keys are drawn the way the macOS menus draw them. (#82)

## [0.4.0] - 2026-10-19

### Added

- Change an app's shortcut by right-clicking a menu entry in the overlay. The
  new keys are saved as an App Shortcut, and ShortcutLens offers to relaunch
  the app. (#60)
- Export the cheat sheet to Markdown or PDF. (#61)
- Favourite shortcuts, shown in a Favourites section at the top of the
  overlay. (#64)
- Practice mode that quizzes you on an app's shortcuts. (#65)
- Named keys such as F1-F19, the arrows, Return and Escape can be recorded in
  the shortcut editor. (#70)

### Changed

- System shortcut labels follow the current keyboard layout. (#66)
- The README explains why per-app shortcuts of sandboxed apps cannot be read
  or edited. (#69)

## [0.3.0] - 2026-10-19

### Added

- A System section with the macOS shortcuts turned on in System Settings, such
  as Spotlight and screenshots. (#53)
- App Shortcuts you defined yourself are marked with a person icon. (#55)
- Conflicts are marked when two entries use the same keys, within the app or
  against a system shortcut. (#56)
- Local shortcut packs add shortcuts that an app does not show in its menus,
  from JSON files. (#57)

## [0.2.0] - 2026-10-18

### Added

- Double-tap Command to open a command palette with search and keyboard
  navigation. (#45, #46)
- Left and Right jump between columns in the palette. (#48)
- Settings window for the trigger delay, menu depth, showing disabled items
  and launch at login. (#50)

### Changed

- Menus are cached per app and reading one stops after 3 seconds, so slow apps
  cannot hold up the overlay. (#49)

## [0.1.0] - 2026-10-18

### Added

- Hold Command to show an overlay with the frontmost app's menu shortcuts,
  grouped by menu. (#38, #40)
- Shortcuts are read from the app's menu bar through the Accessibility API.
  (#30, #36)
- Onboarding for the Accessibility permission. (#37)
- Click an entry to run that menu command. (#41)

### Fixed

- The overlay closes on system shortcuts such as Cmd+Space instead of staying
  open. (#42)

[Unreleased]: https://github.com/MHusted01/shortcutlens/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/MHusted01/shortcutlens/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/MHusted01/shortcutlens/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/MHusted01/shortcutlens/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/MHusted01/shortcutlens/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/MHusted01/shortcutlens/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/MHusted01/shortcutlens/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/MHusted01/shortcutlens/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/MHusted01/shortcutlens/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/MHusted01/shortcutlens/releases/tag/v0.1.0
