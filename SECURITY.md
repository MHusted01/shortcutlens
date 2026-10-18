# Security policy

## Reporting a vulnerability

Please report security issues privately through GitHub:
**Security > Report a vulnerability** on this repository
(private vulnerability reporting). Do not open a public issue.

Include the macOS version, the ShortcutLens version and steps to reproduce.
You can expect a first reply within a week.

## Scope

ShortcutLens uses the macOS Accessibility API to read other apps' menus and
press menu items. Issues of particular interest:

- Ways to make ShortcutLens perform actions the user did not choose
- Reading or exposing more than menu titles and shortcuts
- Any network traffic from the app (it should have none)

## Supported versions

Only the latest release receives fixes.
