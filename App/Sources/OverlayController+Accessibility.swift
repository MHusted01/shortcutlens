import AppKit
import ShortcutLensCore

/// VoiceOver announcements for the palette. The search field keeps keyboard
/// focus while the arrow keys move the selection, so VoiceOver would say
/// nothing; see `PaletteAnnouncement`. The hold-Command overlay announces
/// nothing: it cannot be navigated while Command is held.
extension OverlayController {
    /// Announces the change from `before` to `after`. Closing (`after` nil) is silent.
    func announce(from before: PaletteState<AXUIElement>?, to after: PaletteState<AXUIElement>?) {
        guard NSWorkspace.shared.isVoiceOverEnabled, let after,
              let text = PaletteAnnouncement.text(from: before, to: after)
        else {
            return
        }
        // After the current event, so the panel is on screen and VoiceOver has
        // spoken the focused search field before the announcement.
        DispatchQueue.main.async {
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: text,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
    }
}
