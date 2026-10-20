# Install and update

ShortcutLens needs macOS 14 Sonoma or later and the Accessibility permission
([why](faq.md#why-does-shortcutlens-need-the-accessibility-permission)). The
app is a universal binary (Apple silicon and Intel), ad-hoc signed and not
notarized, so macOS needs two extra steps compared with an App Store app:
removing the quarantine flag, and granting Accessibility again after each
update.

## Install with Homebrew

With [Homebrew](https://brew.sh), from the
[MHusted01/tap](https://github.com/MHusted01/homebrew-tap) tap:

```sh
brew install --cask mhusted01/tap/shortcutlens
xattr -dr com.apple.quarantine /Applications/ShortcutLens.app
```

Homebrew quarantines the app, so the `xattr` line is needed (see
[First launch](#first-launch)). Then open ShortcutLens and
[grant Accessibility](#grant-accessibility).

## Install from the download

1. Download `ShortcutLens-x.y.z.zip` and `ShortcutLens-x.y.z.zip.sha256` from
   [Releases](https://github.com/MHusted01/shortcutlens/releases/latest).
2. In Terminal, in the download folder, check the zip:

   ```sh
   shasum -a 256 -c ShortcutLens-x.y.z.zip.sha256
   ```

   It prints `ShortcutLens-x.y.z.zip: OK`. Anything else means the download is
   damaged or not the published file; download it again.
3. Unzip it, move the app to `/Applications` and remove the quarantine flag:

   ```sh
   ditto -x -k ShortcutLens-x.y.z.zip .
   mv ShortcutLens.app /Applications/
   xattr -dr com.apple.quarantine /Applications/ShortcutLens.app
   ```

4. Open ShortcutLens from `/Applications` and
   [grant Accessibility](#grant-accessibility).

## First launch

Browsers and Homebrew mark downloaded apps with a quarantine flag, and
Gatekeeper blocks a quarantined app that is not notarized:

- macOS 15 and later: "ShortcutLens" Not Opened, with Done and Move to Trash.
  Right-click > Open no longer bypasses this.
- macOS 14: "ShortcutLens" cannot be opened because it is from an
  unidentified developer. Right-click > Open, then Open, also works here.

`xattr -dr com.apple.quarantine /Applications/ShortcutLens.app` removes the
flag, and the app then opens normally (checked on macOS 14, 15, 26 and 27).

## Grant Accessibility

On first launch, a short onboarding in three steps shows what the app does
and how to use it. The last step opens System Settings > Privacy & Security >
Accessibility; switch ShortcutLens on there, and the onboarding shows a green
checkmark. Reopen it any time with "Welcome to ShortcutLens…" in the menu bar
menu.

ShortcutLens has no Dock icon; it lives in the menu bar.

## Update

macOS ties the Accessibility permission to the app's signature. An ad-hoc
signature changes with every release, so macOS treats each update as a new
app and the old permission no longer applies.

1. Quit ShortcutLens (menu bar icon > Quit ShortcutLens).
2. Replace the app:
   - Homebrew: `brew upgrade --cask shortcutlens`, then run the `xattr` line
     again; Homebrew quarantines every upgrade.
   - Download: move the old `/Applications/ShortcutLens.app` to the Trash,
     then install the new zip as in
     [Install from the download](#install-from-the-download).
3. In System Settings > Privacy & Security > Accessibility, select the old
   ShortcutLens entry and remove it with the minus button.
4. Open ShortcutLens and grant Accessibility again. If the app is not in the
   list, add it with the plus button from `/Applications`. If the switch is on
   but the overlay does not appear, remove the entry and add it again.

Settings, favourites and packs are kept.

## Uninstall

1. Quit ShortcutLens.
2. Remove the app: `brew uninstall --cask shortcutlens`, or move
   `/Applications/ShortcutLens.app` to the Trash.
3. Remove its entry in System Settings > Privacy & Security > Accessibility.
4. Optional, to delete settings, favourites and packs as well: with Homebrew,
   use `brew uninstall --zap --cask shortcutlens` in step 2. Otherwise delete
   `~/Library/Application Support/ShortcutLens` and
   `~/Library/Preferences/io.github.mhusted01.shortcutlens.plist`.
