# App icon

Original artwork for ShortcutLens: a magnifying glass with the Command symbol
in the lens. Chosen in #85 from three concepts. No CheatSheet assets are used.

## Files

| Path | What |
| --- | --- |
| `App/Resources/AppIcon.icon/` | The icon the app ships. Icon Composer format: `icon.json` plus one SVG per layer in `Assets/`. |
| `design/icon/ShortcutLens.svg` | Flat master on the classic 1024 grid (824 pt rounded square). Use it for the README, the social preview and anything outside the app. |
| `design/icon/concepts/` | The three concepts from #85 (`a-keycap`, `b-lens`, `c-overlay`) and `sheet.png`, the comparison sheet. Kept for reference only. |

## Layers

`AppIcon.icon` has a system gradient fill (`automatic-gradient`, blue) and two
groups, front to back:

1. `command.svg` - the Command symbol, opaque.
2. `lens.svg` and `handle.svg` - the glass and the handle, slightly
   translucent so Liquid Glass shows through.

Layers are drawn on the full 1024 x 1024 canvas; the system applies the mask,
so they do not include the rounded square or a background.

## How it is built

`project.yml` adds `AppIcon.icon` to the app's resources and sets
`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. On build, `actool` compiles it
into `Assets.car` (Liquid Glass, light, dark and tinted appearances on
macOS 26+) and an `AppIcon.icns` fallback for macOS 14-15. No exported PNGs
are committed.

## Changing the icon

- Edit the layer SVGs in `App/Resources/AppIcon.icon/Assets/` and
  `icon.json` by hand, or open `AppIcon.icon` in Icon Composer
  (`Xcode.app/Contents/Applications/Icon Composer.app`) to tune glass,
  shadow and the dark and tinted variants.
- Keep `design/icon/ShortcutLens.svg` in step with the layers.
- Check the result in a build: `make build`, then look at the app in Finder
  and in the About box (menu bar icon > About ShortcutLens), in light and dark
  mode.

Preview a layer or the master without Xcode:

```sh
rsvg-convert -w 512 design/icon/ShortcutLens.svg -o /tmp/icon.png
```
