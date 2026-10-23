import AppKit
import SwiftUI

/// Owns the current `OverlayPanel` for the overlay and the palette, and
/// replaces it when macOS shows it on the wrong Space.
///
/// Once shown over a fullscreen app, a panel can stay tied to that app's
/// Space: ordered front later on the desktop the fullscreen Space came from,
/// it appears on the fullscreen Space instead (#146). A fresh panel is never
/// affected, so `present` swaps in a new one when the panel is not on the
/// active Space after it was ordered front.
@MainActor
final class OverlayPanelHost {
    private(set) var panel = OverlayPanel()

    /// Called when the palette panel stops being key; moves to every new panel.
    var onResignKey: () -> Void = {} {
        didSet { panel.onResignKey = onResignKey }
    }

    /// Presents `view` like `OverlayPanel.present`, in a new panel when the
    /// current one ends up on another Space.
    func present(_ view: some View, frame: CGRect, takesKeyboard: Bool = false) {
        panel.present(view, frame: frame, takesKeyboard: takesKeyboard)
        guard !panel.isOnActiveSpace else {
            return
        }
        OverlayLog.logger.notice("panel not on the active Space, replaced")
        // Dismissing first drops key status without reporting it, so the
        // palette stays open.
        panel.dismiss()
        panel = OverlayPanel()
        panel.onResignKey = onResignKey
        panel.present(view, frame: frame, takesKeyboard: takesKeyboard)
    }
}
