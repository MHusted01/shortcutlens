# Privacy

ShortcutLens collects nothing and sends nothing.

- No analytics, telemetry, crash reporting or usage tracking.
- No network access: the app contains no networking code and no automatic
  update checks. Updates are downloaded manually from GitHub Releases.
- No third-party code is linked into the app.
- Settings and any data you create stay on your Mac.

## Why it needs the Accessibility permission

ShortcutLens reads the menu bar of the app in front (menu titles and their
keyboard shortcuts) through the macOS Accessibility API, and presses a menu
item when you click it in the overlay. It does not read window contents,
typed text or other apps' documents, and it does not store what it reads.

## Reading sandboxed apps' App Shortcuts (optional)

The setting "Mark App Shortcuts in sandboxed apps" is off by default. When you
turn it on, ShortcutLens reads one file of the app in front:
`~/Library/Containers/<app>/Data/Library/Preferences/<app>.plist`, and only
its App Shortcuts entry. macOS asks first whether ShortcutLens may access
data from other apps. The file is never changed and nothing from it is
saved. Turn the setting off, or remove ShortcutLens in System Settings >
Privacy & Security, to stop it.

## How this is enforced

Every pull request runs `scripts/check-no-telemetry.sh`, which fails the build
if networking APIs or third-party packages appear in the shipped code.
