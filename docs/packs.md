# Shortcut packs

A shortcut pack lists keyboard shortcuts that an app has but does not show in
its menus, such as Space for Quick Look in Finder. ShortcutLens shows a pack's
sections after the app's menus and before the System section. Pack rows are
display-only: clicking them does nothing. They take part in conflict
detection, so a pack shortcut that uses the same keys as a menu item or a
system shortcut is marked on both rows.

Packs are plain JSON files on your Mac. ShortcutLens never downloads or
uploads them.

## Where packs live

- Your packs: `~/Library/Application Support/ShortcutLens/Packs/*.json`.
  Settings > Shortcut packs > Show Packs Folder creates and opens the folder.
- Bundled examples: inside the app (`Contents/Resources/Packs`). The app ships
  one for Finder, [`com.apple.finder.json`](../App/Resources/Packs/com.apple.finder.json).

Files are read again every time the overlay reads an app, so an edited pack
shows up the next time you hold Command. Only files ending in `.json` are read.

If one of your packs has the same `bundleIdentifier` as a bundled pack, yours
replaces the bundled one. Several of your own packs for one app are all used,
in file name order.

## Format (schema version 1)

```json
{
  "schemaVersion": 1,
  "bundleIdentifier": "com.apple.finder",
  "name": "Finder extras",
  "sections": [
    {
      "title": "Selection",
      "shortcuts": [
        { "title": "Quick Look selected items", "key": "Space" },
        { "title": "Open selected item", "key": "Down", "modifiers": ["command"] },
        { "title": "Select previous item", "key": "Tab", "modifiers": ["shift"] }
      ]
    }
  ]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `schemaVersion` | yes | Must be `1`. |
| `bundleIdentifier` | yes | The app the pack is for. Find it with `osascript -e 'id of app "Finder"'`. |
| `name` | no | A name for the pack. |
| `sections` | yes | Groups shown as overlay sections, in order. May be empty. |
| `sections[].title` | yes | The section heading. |
| `sections[].shortcuts` | yes | The shortcuts in the section. |
| `shortcuts[].title` | yes | What the shortcut does. |
| `shortcuts[].key` | yes | One character (`"K"`, `"/"`, case does not matter) or a key name below. |
| `shortcuts[].modifiers` | no | Any of `"control"`, `"option"`, `"shift"`, `"command"`. Omitted or empty means the key alone. |

Text fields must not be empty. Unknown extra fields are ignored. Files larger
than 256 KB are not read.

Unlike menu items, a pack shortcut does not get Command automatically: list
`"command"` when the shortcut uses it.

### Key names

Names are case-sensitive.

`Space`, `Return`, `Enter`, `Tab`, `Escape`, `Delete` (backspace),
`ForwardDelete`, `Clear`, `PageUp`, `PageDown`, `Home`, `End`, `Left`,
`Right`, `Up`, `Down`, `Help`, `F1` to `F19`.

## Errors

A pack with a problem is skipped and listed in Settings > Shortcut packs with
its file name and the reason. The other packs still load. Reasons include:

- `Not valid JSON.`
- `Unsupported schemaVersion 2; this version reads 1.`
- `Missing field "sections[0].shortcuts[1].key".`
- `Invalid "sections[0].shortcuts[1].modifiers": unknown modifier "hyper".`
- `Invalid "bundleIdentifier": must not be empty.`
- `File is larger than 256 KB.`

Settings reads the files when the window opens; press Reload after editing a
pack to update the list.

## Versioning

`schemaVersion` changes only when a change would make older ShortcutLens
versions misread a file. A file with a version this build does not know is
reported, never partly loaded.
