# Privacy

ShortcutLens collects nothing and sends nothing.

- No analytics, telemetry, crash reporting or usage tracking.
- No network access: the app contains no networking code and no automatic
  update checks. Updates are downloaded manually from GitHub Releases.
- No third-party code is linked into the app.
- Settings and any data you create stay on your Mac.

## Why it needs the Accessibility permission

ShortcutLens needs Accessibility to read the menus of the app you're using and
to click a menu item when you choose it. It doesn't read what's in your
windows or what you type, and it doesn't save what it reads.

It uses the macOS Accessibility API for this: it reads the menu titles and
keyboard shortcuts in the menu bar of the app in front, and presses a menu
item when you click it in the overlay.

## How this is enforced

Every pull request runs `scripts/check-no-telemetry.sh`, which fails the build
if networking APIs or third-party packages appear in the shipped code.
