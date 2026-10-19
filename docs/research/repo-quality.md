# What a high-quality macOS app repo looks like

Research for #84, done 2026-10-19. The goal is to know what to aim for before
the Phase 6 clean-up (#85-#88) and to turn that into a checklist with an owner
issue per item.

## Repos studied

Seven popular open-source macOS utilities, all small native menu bar or
background apps like ShortcutLens. Data from the GitHub API and the files on
each default branch on 2026-10-19.

| Repo | Stars | Licence | Website | Topics | Wiki | Discussions | Social preview |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [rxhanson/Rectangle](https://github.com/rxhanson/Rectangle) | 30k | MIT-style (custom) | rectangleapp.com | none | on | on | custom |
| [jordanbaird/Ice](https://github.com/jordanbaird/Ice) | 30k | GPL-3.0 | icemenubar.app | 10 | off | on | default |
| [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos) | 16k | GPL-3.0 | alt-tab.app | 8 | off | off | default |
| [p0deje/Maccy](https://github.com/p0deje/Maccy) | 22k | MIT | maccy.app | 3 | off | on | default |
| [exelban/stats](https://github.com/exelban/stats) | 43k | MIT | mac-stats.com | 14 | off | off | custom |
| [MonitorControl/MonitorControl](https://github.com/MonitorControl/MonitorControl) | 35k | MIT | monitorcontrol.app | 18 | on | on | default |
| [dwarvesf/hidden](https://github.com/dwarvesf/hidden) | 15k | MIT | d.foundation | 3 | on | on | default |

| Repo | Issue templates | `config.yml` | CHANGELOG file | Community files | Homebrew |
| --- | --- | --- | --- | --- | --- |
| Rectangle | bug, feature (Markdown) | no | no | CoC, CONTRIBUTING, SECURITY, FUNDING | `brew install --cask rectangle` |
| Ice | bug, feature (forms) | blank issues off | no | CoC, FUNDING, FREQUENT_ISSUES | official cask |
| AltTab | bug, feature, other (Markdown) + PR template | no | `changelog.md` (generated) | FUNDING | official cask |
| Maccy | bug, feature (forms) | blank issues on | no | FUNDING | `brew install maccy` |
| Stats | bug, feature (forms) | blank issues off, links to search + FAQ | no | FUNDING | `brew install stats` |
| MonitorControl | 6 forms (bug, feature, monitor, question, discussion) | yes | no | FUNDING, stale bot | official cask |
| Hidden Bar | none | no | `CHANGELOG.md` (Keep a Changelog style) | CONTRIBUTING, PRIVACY_POLICY | official cask + App Store |

## Per-repo notes

**Rectangle.** The README starts with one sentence and one large screenshot,
then system requirements and install (download + Homebrew). The rest is a long
user manual in the README (snap areas, hidden preferences, known issues,
uninstall). Strong on content, weak on scannability: the first screen sells
nothing beyond the screenshot. Release notes are GitHub's generated "What's
Changed" list with contributor credits.

**Ice.** The best first screen of the group: centred app icon and name, one
sentence, a wide banner image, then a row of flat badges (download, platform,
"macOS 14+", website, licence). Install comes next (zip + Homebrew), then a
feature list written as a roadmap with checkboxes. A short "Why macOS 14+?"
section pre-empts a common question. Issue forms with a required "I searched
existing issues" checkbox and required app and macOS version fields; blank
issues are off. Release notes are hand-written "What's New / Bug Fixes"
sections.

**AltTab.** The README is just a banner image linking to the website; all
documentation lives on alt-tab.app. Works for a project with a full site, not
for us. Uses semantic-release with conventional commits, so `changelog.md` and
release notes are generated from commit messages and grouped into
Features / Bug Fixes. Closest match to our squash-merge workflow.

**Maccy.** Small icon, name, two badges (downloads, build), one paragraph and
the supported macOS version on the first screen, then a table of contents.
Feature list is five short bullets ("Lightweight and fast", "Keyboard-first",
"Secure and private", ...) - a good model for ours. Usage, advanced settings
and an FAQ follow. Has a `Designs/` folder with icon sources. Release notes are
a hand-written flat list ("Added ...", "Fixed ... (#1473)").

**Stats.** Icon, two screenshots, one-line tagline ("macOS system monitor in
your menu bar"), then install (direct download link to the latest asset,
Homebrew, uninstall), requirements, features, a long FAQ. Issue `config.yml`
turns blank issues off and adds contact links to issue search and the FAQ -
cheap and effective. Release notes grouped into "Bug fixes / New features"
with conventional-commit prefixes.

**MonitorControl.** Icon left, name + two-line pitch + "Download for macOS"
button right, then badges (downloads, version, licence, platform) and a big
screenshot. Install is a short "Download" section near the top; "How to build"
is at the end. Many issue forms, including a hardware-specific one. Uses the
Wiki for per-display compatibility notes.

**Hidden Bar.** Centred icon, badges, one sentence, two screenshots, install
(App Store, Homebrew, manual). Uses emoji headings (not for us). Keeps a
Keep a Changelog `CHANGELOG.md` with dates and Added / Fixed sections and
links issue numbers. Release notes carry user-facing warnings ("Before you
install on macOS 27"). Has a separate privacy policy file.

## Patterns

What almost every repo does:

1. **The first screen sells the app.** App icon, name, one sentence, a
   screenshot or banner, and a visible download link - before any detail.
2. **Install comes first, building comes last.** Download link + Homebrew
   one-liner near the top; "How to build" or "Development" at the bottom.
3. **Requirements are stated once, near install** ("macOS 14 or later"),
   often also as a badge.
4. **Short feature list in the README**, long feature docs elsewhere (a
   website, an FAQ section or `docs/`).
5. **Issue forms over Markdown templates** (4 of 6 that have templates),
   with required app version and macOS version fields.
6. **A website as homepage.** Without a website, the Releases page is the
   natural homepage.
7. **Homebrew.** All seven are in the official `homebrew/cask` tap and most
   READMEs show the one-liner. The official tap expects signed, notarized
   apps, so without a paid developer account we use a personal tap (#102).

What is common but not universal:

- Badges: 4 of 7. Flat `shields.io` badges for download/release, platform,
  macOS version and licence. Build-status badges are rare (1 of 7).
- Topics: 6 of 7, typically `macos`, `swift`, `menubar`, `macos-app` plus
  domain words.
- An FAQ / known issues section: 4 of 7 (Rectangle, Ice, Maccy, Stats).
  Typically covers permissions (Accessibility, Screen Recording) and "app
  does not appear".
- A changelog file: only 2 of 7. The others rely on GitHub Releases. Both
  approaches are fine if release notes are grouped and readable.
- Custom social preview: only 2 of 7, but those two look clearly better when
  shared.

What we should not copy:

- README as a full manual (Rectangle, Stats) - hard to scan.
- README with no text (AltTab) - only works with a real website.
- Emoji headings, donation buttons, "love" badges.
- A Wiki or Discussions we do not maintain (decision: issues only).

## Where ShortcutLens stands (v1.0.0)

Already good:

- `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, `PRIVACY.md`, PR template,
  Dependabot.
- CI on every PR (lint, test with coverage gate, build, no-telemetry,
  PR title), protected `main`, tagged releases with zip + SHA-256.
- Conventional-commit squash merges, so every change already has a typed
  one-line summary.
- `docs/packs.md` and a translation guide; English and Danish UI.

Gaps:

- No app icon; the README has no image at all.
- README opens with a long status list; install is near the end, after the
  feature details; no badges.
- No issue templates or `config.yml`; blank issues only.
- No `CODE_OF_CONDUCT.md`, no `CHANGELOG.md`.
- Release notes are GitHub's generated "What's Changed" list: it repeats PR
  titles and does not separate features from fixes.
- No topics, no homepage, no social preview; the Wiki is on but empty.
- No FAQ or troubleshooting section, although we know the common questions
  (Accessibility permission lost after an update, ad-hoc signing and the
  Gatekeeper prompt, CheatSheet conflict, Chromium apps).
- `.ruff_cache/` is not ignored.
- No Homebrew install yet.

## Checklist for ShortcutLens

Priority: **P1** = do in Phase 6, **P2** = do when the owner issue comes up,
**P3** = optional. Each item names its owner issue, either on the item or in
its section heading (#87, #88).

### Identity

- [ ] P1 App icon in Finder, Dock, About box and release zip; SVG sources in `design/icon/` - #85
- [ ] P1 Menu bar template icon derived from the app icon - #86
- [ ] P1 Social preview image (1280x640) built from the icon and tagline - #87

### README (#88)

- [ ] P1 Hero: icon, name, one-line tagline, badges (release, CI, licence, "macOS 14+")
- [ ] P1 Install section directly after the hero: download link to the latest release zip, requirements, first-launch steps for an ad-hoc signed app (Gatekeeper, Accessibility permission)
- [ ] P1 Feature list of 5-8 short bullets (Maccy style); details move to `docs/` pages (palette, export, editing, practice, settings)
- [ ] P1 Privacy / no-telemetry stated in one line in the hero area and linked to `PRIVACY.md`
- [ ] P1 FAQ / troubleshooting page in `docs/` (permission lost after update, overlay does not appear, CheatSheet conflict, Chromium apps) and linked from the README and the issue `config.yml`
- [ ] P1 Development section last
- [ ] P2 Screenshot placeholders filled with real screenshots and a demo GIF - #95

### GitHub settings and community files (#87)

- [ ] P1 Issue forms: bug (required app version, macOS version, "I searched existing issues"), feature request, translation
- [ ] P1 `config.yml`: blank issues off, contact links to issue search and the FAQ page
- [ ] P1 `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1)
- [ ] P1 `CHANGELOG.md` in Keep a Changelog format, backfilled v0.1.0-v1.0.0 with dates and Added / Changed / Fixed
- [ ] P1 Topics: `macos`, `macos-app`, `swift`, `swiftui`, `appkit`, `menubar`, `keyboard-shortcuts`, `accessibility`, `productivity`, `cheatsheet`, `privacy`
- [ ] P1 Homepage: the Releases page
- [ ] P1 Wiki off; Discussions stay off
- [ ] P1 `.ruff_cache/` in `.gitignore`

### Releases

- [ ] P1 Release notes for v1.1.0 grouped into Added / Changed / Fixed, written from `CHANGELOG.md` instead of the generated PR list - #89
- [ ] P2 Release notes include a short "Before you install" note when a version needs a permission re-grant (ad-hoc signing) - #89, #96, #101, #104
- [ ] P3 `release.yml` uses the matching `CHANGELOG.md` section as the release body, so notes are not written twice - #89

### Distribution (Phase 9)

- [ ] P2 Personal Homebrew tap with a cask (`brew install --cask mhusted01/tap/shortcutlens`) - #102
- [ ] P2 Install and update guide covering Gatekeeper, quarantine and permissions - #103
- [ ] P2 README install section gets the Homebrew one-liner - #102

### Not doing

- Website, Discussions, Wiki, FUNDING / donation links, README translations,
  stale bot, App Store release, notarization (no paid developer account).
