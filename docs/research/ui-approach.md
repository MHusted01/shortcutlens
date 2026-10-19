# UI approach and visual spec

Research for #90, done 2026-10-19. Phase 7 (v1.2.0) changes how the overlay,
palette, settings and onboarding look. This document decides the direction
first. It ends in a spec that #91-#96 implement and test against. Each
Phase 7 issue links to its section here.

## Where the UI is today

Read from the code on `main` at v1.1.0.

| Surface | Window | Material | Notable values |
| --- | --- | --- | --- |
| Overlay | Borderless non-activating `NSPanel`, `.statusBar` level, `animationBehavior = .none` | `NSVisualEffectView`, `.hudWindow`, behind window, always `.active` | Corner radius 14. `PanelLayout.Metrics.standard`: padding 20, header 40, columns 260 wide with 24 between them, rows 20, section titles 24, 14 between sections, at most 90% of the visible screen |
| Palette | Same panel, made key | Same | Search field: borderless `NSTextField`, system font 15, no focus ring. Selection: accent at 35%. Hover: primary at 10%. Highlight radius 5, inset 4 |
| Settings | Titled `NSWindow` with a SwiftUI `Form` (`.grouped`) | Window default | One column, 380 wide, five sections |
| Onboarding | Titled `NSWindow`, one screen | Window default | 440 wide, padding 20, spacing 12, `keyboard` symbol as the icon |

Core computes the overlay's row layout before rendering, with fixed heights
(`PanelLayout`). Any spacing change in the overlay is a change to
`PanelLayout.Metrics.standard` and its tests, not only to the view.

These work and stay:

- The dense layout in several columns.
- Keys as plain right-aligned text, as in macOS menus.
- The hover and selection model.
- The VoiceOver structure: sections are headers, and row labels come from
  `PaletteAnnouncement`.

These look dated:

- The overlay uses a HUD material on macOS 26 and later, where system panels
  and Spotlight use Liquid Glass.
- The panel pops in and out with no transition.
- The palette search field has no visual container.
- Settings is one long form.
- Onboarding is a plain, alert-like block of text.

## Research

### Apple Human Interface Guidelines

- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials):
  Liquid Glass is for the layer of controls and navigation that floats above
  content. Use it sparingly, and never as a background in the content layer.
  The regular variant keeps text legible and suits "components [that] have a
  significant amount of text, such as alerts, sidebars, or popovers". The clear
  variant is only for components over visually rich media. Both variants
  change appearance under Reduce Transparency and Increase Contrast. On macOS,
  standard materials (`NSVisualEffectView.Material`) are chosen by semantic
  purpose, with vibrant colours on top.
- [Panels](https://developer.apple.com/design/human-interface-guidelines/panels):
  a panel floats above other windows, supports the main task and hides when
  it isn't needed. The overlay fits this: it is transient, has no title bar
  and does not take focus away from the frontmost app.
- [Motion](https://developer.apple.com/design/human-interface-guidelines/motion):
  motion should be brief and purposeful and never delay the user. With Reduce
  Motion, replace movement (scale, slide) with a dissolve or no animation.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography):
  macOS body text is 13 pt. Use the built-in text styles so that weights and
  leading stay consistent.
- [Settings](https://developer.apple.com/design/human-interface-guidelines/settings):
  a Mac settings window with several groups has a toolbar of tabs. It opens
  on the last tab used, and the window title is the tab's name.
- [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding):
  keep it short and skippable, teach by showing, and ask for a permission
  only when it is clear why it is needed.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility):
  support Reduce Transparency, Increase Contrast, Reduce Motion and VoiceOver.
  Never use colour as the only signal.

### Liquid Glass in AppKit

Read from the macOS 27 SDK header `NSGlassEffectView.h` and WWDC25
["Meet Liquid Glass"](https://developer.apple.com/videos/play/wwdc2025/219/)
and ["Build an AppKit app with the new design"](https://developer.apple.com/videos/play/wwdc2025/310/).

- [`NSGlassEffectView`](https://developer.apple.com/documentation/appkit/nsglasseffectview)
  (macOS 26+) has a `contentView`, `cornerRadius`, `tintColor` and `style`
  (`.regular` or `.clear`). The content goes in `contentView`, not
  `addSubview`, so the glass can treat it as foreground.
- `effectIsInteractive` exists only from macOS 27. CI builds with
  `latest-stable` Xcode, so the overlay doesn't use it. Rows have their own
  hover feedback.
- `NSGlassEffectContainerView` merges nearby glass views. The overlay is a
  single glass surface, so it isn't needed.
- The glass corner radius must match the window's shape, or unblurred
  pixels show at the corners. The panel is borderless, so the glass view is
  the only shape.
- There is no opacity control, and the system handles Reduce Transparency and
  Increase Contrast. If a manual check shows that it doesn't, the fallback is
  an opaque `windowBackgroundColor` surface, not a lower alpha.
- Fallback on 14 and 15: `NSVisualEffectView`. The current `.hudWindow` is
  dark in both appearances. `.popover` follows light and dark mode, like the
  glass does, so light and dark look alike on all versions.
- Windows with a title bar (settings, onboarding) get the new design
  from the SDK. Standard SwiftUI controls and `Form` adapt by
  themselves, so they need no custom material.

### Comparable apps

This covers only how they behave and how they're laid out. Nothing is copied.

- **Spotlight (macOS 26):** one glass surface with a large search field at the
  top and results below it. It has no title bar. Selection is a filled,
  rounded rectangle.
- **Raycast:** a centred panel with the search field as its header and a list
  below. A footer shows the available actions, with their keys as small key
  caps there instead of in every row. The selection fill spans the full row
  width.
- **KeyClu:** a cheat sheet shown while a modifier is held, with sections in
  columns. Each row is the command name with the keys right-aligned, as in
  CheatSheet.
- **CheatSheet (behaviour only):** hold Command to show it and release to hide
  it. It is a dark, blurred panel with sections in columns.

What this means for ShortcutLens:

- Keep keys as plain text in rows. Key caps on every row would double the
  visual noise in apps with 200+ shortcuts.
- Make the search field a clearly bounded control.
- Use a short fade that never delays the first readable frame.

### Accessibility settings

| Setting | How the app learns it | Where it applies |
| --- | --- | --- |
| Reduce Transparency | `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency`, SwiftUI `\.accessibilityReduceTransparency` | Panel material |
| Increase Contrast | `accessibilityDisplayShouldIncreaseContrast`, SwiftUI `\.colorSchemeContrast` | Borders, highlights, separators |
| Reduce Motion | `accessibilityDisplayShouldReduceMotion`, SwiftUI `\.accessibilityReduceMotion` | Show/hide, step transitions |
| Changes while running | `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` on `NSWorkspace.shared.notificationCenter` | The overlay reads the flags each time it shows, so it needs no observer |
| VoiceOver | Existing labels, header traits, `PaletteAnnouncement` | Unchanged; new elements follow the same pattern |

## Visual spec

The values are in points. Use the semantic names in code (a private `static
let` per view, as now). Never write raw colour literals. "26+" means
`if #available(macOS 26, *)`. "14/15" is the else branch.

### Spec: tokens

**Spacing.** The scale has a 4 pt base: 4, 8, 12, 16, 20, 24. New code uses no
other values. An existing value off this scale moves onto it when its surface
is next changed: section spacing in the overlay goes from 14 to 16.

**Type scale.** Use only the built-in text styles:

| Use | Style |
| --- | --- |
| Overlay app name | `.title3.weight(.semibold)` |
| Onboarding step title | `.title2.weight(.semibold)` |
| Section title | `.headline` |
| Row title, row keys, body text | `.body` |
| Search field | 15 pt system (matches `.title3`) |
| Secondary notes (conflict caption, hints) | `.caption` in the overlay, `.callout` in windows |

**Colours.** Use only semantic colours. System colours have their own
Increase Contrast variants.

| Role | Colour |
| --- | --- |
| Primary text | `.primary` |
| Keys, hints, placeholders | `.secondary` |
| Disabled row | Whole row at 40% opacity (current) |
| Hover highlight | `.primary` at 8% |
| Selection highlight | `Color.accentColor` at 30%. Under Increase Contrast it also gets a 1 pt accent stroke |
| Conflict | `systemOrange` (text, keys and symbol) |
| Favourite star | `systemYellow` |
| Custom shortcut marker | `.tint` |
| Errors in windows | `.red` (current) |
| Separators | `Divider()` / `separatorColor` |

Colour is never the only signal. The star, custom marker and conflict marker
are symbols, and each row's VoiceOver label already says what they mean.

**Corner radii.**

| Element | 26+ | 14/15 |
| --- | --- | --- |
| Overlay and palette panel | 18 | 14 |
| Row highlight (hover, selection) | 6 | 5 |
| Search field container | 8 | 6 |

**Materials.**

| Surface | 26+ | 14/15 | Reduce Transparency |
| --- | --- | --- | --- |
| Overlay, palette | `NSGlassEffectView`, `.regular`, no tint, radius 18 | `NSVisualEffectView`, `.popover`, `.behindWindow`, `.active`, radius 14 | Rely on the system (both adapt). If a manual check shows see-through glass, use an opaque `windowBackgroundColor` |
| Settings, onboarding | System window (new design from the SDK) | System window | System |

Under Increase Contrast, the overlay panel gets a 1 pt inner border in
`separatorColor` if the system doesn't already draw one. Check it by hand on
26+ and on 14/15.

**Animation.**

| Event | Normal | Reduce Motion |
| --- | --- | --- |
| Overlay show | Alpha 0 -> 1 and scale 0.98 -> 1, over 0.12 s, ease-out | Alpha only, 0.12 s |
| Overlay hide (Command released, Escape) | Alpha 1 -> 0 over 0.08 s, ease-in | Same (a fade is not motion) |
| Overlay hide after a row click | Immediate. The menu action runs first | Immediate |
| Palette selection move | None: the highlight jumps, and scrolling is not animated | None |
| Onboarding step change | Cross-fade and 8 pt slide, 0.2 s | Cross-fade, 0.2 s |
| Settings tab change | System | System |

Rules:

- No animation delays the first frame that shows content. The panel is ordered
  front at alpha 0 in the same turn of the run loop in which the read
  finishes.
- A new show during a hide cancels the hide.
- No springs or bounces.

### Spec: overlay

Implemented by #91.

- **Material:** as in the tokens. On 26+ the SwiftUI content goes in the glass
  view's `contentView`, and on 14/15 in the effect view. `OverlayPanel` picks
  one when it is created.
- **Header:** app icon 28 x 28, app name `.title3` semibold, height 40. A
  `Divider()` sits below it, inset to the content padding.
- **Layout:** `PanelLayout.Metrics.standard` keeps padding 20, column width
  260, column spacing 24, row height 20 and section title height 24. Section
  spacing changes to 16. Update `PanelLayoutTests` in the same PR.
- **Section titles:** `.headline`, `.primary`, one line, header trait (current).
- **Rows:**
  - Title on the left. Markers, then keys, on the right, with spacing 8.
  - Keys are plain `.secondary` text with `.monospacedDigit()`, with no key
    caps.
  - Hover and selection highlights use the colours and radii above. They
    extend 4 pt beyond the row and span the full column width.
- **Markers:** star, custom and conflict symbols at `.imageScale(.small)`, in
  that order, before the keys. The conflict caption is a second line in
  `.caption` orange (current).
- **States:** while loading, a small `ProgressView` in the centre. When empty,
  "No keyboard shortcuts" in `.secondary` in the centre. The placeholder panel
  is 360 x 150.
- **Animation:** show and hide as in the animation table. Replace
  `animationBehavior = .none` with an explicit alpha animation, either in an
  `OverlayController+*.swift` extension or in `OverlayPanel`.
  `OverlayController.swift` must stay under its line limit.
- **Check:**
  - Light, dark, Increase Contrast and Reduce Transparency, on 26+ and on
    14 or 15.
  - Time to show is not slower than before. Log timestamps from the trigger
    to `orderFrontRegardless`.

### Spec: palette

Implemented by #92. Everything in the overlay spec applies too.

- **Search field:**
  - Sits in the header after the app name and fills the remaining width, at
    least half a column.
  - A rounded container (radius 8 on 26+, 6 on 14/15) filled with `.primary`
    at 6%, with 8 pt horizontal padding.
  - A leading `magnifyingglass` symbol in `.secondary`, hidden from VoiceOver.
    The field keeps its own accessibility label.
  - Text is 15 pt.
- **Focus:** the field always has focus while the palette shows, so there's
  no system focus ring. The container shows focus with a 1 pt accent stroke,
  or 2 pt under Increase Contrast.
- **Selection:** the accent fill (30%) spans the full column width.
  Arrow keys move it, with no animation. Hover still shows on other rows.
- **No matches:**
  - A centred `magnifyingglass` symbol (`.title2`, `.secondary`) above "No
    matching shortcuts" in `.body` `.secondary`.
  - VoiceOver announces the text when the state appears, the same way as
    `PaletteAnnouncement`.
  - New strings get en and da entries.
- **Keyboard:** no change to the commands in `SearchField` and
  `PaletteState`.

### Spec: settings

Implemented by #93.

- **Window:**
  - A SwiftUI `Settings` scene with a `TabView`, which gives toolbar tabs with
    a symbol and a label.
  - The menu opens it with `SettingsLink` or `openSettings`. It activates the
    app first, because the app is an `LSUIElement`.
  - The window title is the tab name.
  - The scene remembers the last tab with `@AppStorage`.
- **Tabs and contents.** The settings stay the same and are only regrouped:

  | Tab | Symbol | Sections |
  | --- | --- | --- |
  | General | `gearshape` | Trigger (hold-delay slider), Startup (launch at login and its note) |
  | Overlay | `rectangle.grid.2x2` | Show disabled items, show system shortcuts |
  | Packs | `shippingbox` | Packs in use, problems, Reload, Show Packs Folder |
  | Advanced | `slider.horizontal.3` | Menu depth |

- **Layout:** each tab is a `Form` with `.formStyle(.grouped)`, 450 wide, with
  its height fitted to the content. The window resizes per tab. Section titles
  come from the system. Help text sits under the control it explains, in
  `.callout` `.secondary`.
- **Colours:** errors stay `.red` in `.callout`, as now.

### Spec: onboarding

Implemented by #94.

- **Window:** titled, closable and not resizable, 480 wide, with content
  padding 24. It is centred on first show.
- **Steps:** there are three. Each has a 64 pt visual at the top, a
  `.title2` semibold title and one or two short paragraphs in `.body`.
  1. *What it does*: the app icon at 64 pt, the app name and a one-line
     description.
  2. *How to use it*: a `command` symbol at 64 pt in `.tint`, then two lines:
     "Hold Command" (the overlay) and "Press Command twice" (the palette).
  3. *Allow Accessibility*: a `hand.raised` symbol in `.tint`, then today's
     explanation, the no-data line and the instructions. When the permission
     is detected, the step shows a `checkmark.circle.fill` in `.green` with
     "Ready", and the window closes after 1 s.
- **Navigation:**
  - Footer left: "Step N of 3" in `.callout` `.secondary`. VoiceOver reads
    it, and it replaces page dots, so the position is not shown by colour
    only.
  - Footer right, spacing 8: Skip (cancel action), Back (from step 2), and
    Continue or Open System Settings (default action).
- **Transition:** as in the animation table. VoiceOver focus moves to the new
  step's title.

### Spec: screenshots and release

#95 and #96 don't change the UI.

- Screenshots show:
  - The overlay in light and dark on macOS 26.
  - The palette with a query and a selection.
  - Each settings tab.
  - Each onboarding step.
- #95 notes which macOS version the screenshots come from.
- The v1.2.0 release notes link to this document for the visual changes.

## Out of scope

- Custom themes, user-chosen colours or a per-app accent.
- Key caps in rows (rejected above because of density).
- Tinted glass.
- `effectIsInteractive`, which needs the macOS 27 SDK on CI.
