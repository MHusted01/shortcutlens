import AppKit
import ShortcutLensCore

/// Running the menu item behind a row.
extension OverlayController {
    /// Hides the panel and presses the row's menu item in the target app. Beeps
    /// when the item was not run (disabled, stale or an AX error).
    ///
    /// The press runs off the main actor because it can wait up to the AX
    /// messaging timeout. The target app stays frontmost throughout: the panel
    /// never activates ShortcutLens.
    func run(_ row: OverlayRow<AXUIElement>) {
        guard row.isEnabled, let element = row.element.map(UncheckedSendable.init) else {
            return
        }
        hide()
        Task.detached(priority: .userInitiated) {
            let outcome = MenuItemRunner(client: SystemAXClient()).run(element.value)
            // A fixed outcome string only, never the menu title.
            let description = outcome.logDescription
            guard outcome != .pressed else {
                OverlayLog.logger.notice("menu item \(description, privacy: .public)")
                return
            }
            OverlayLog.logger.error("menu item not run: \(description, privacy: .public)")
            // The panel is already hidden, so the beep is the only sign the click did nothing.
            await MainActor.run { NSSound.beep() }
        }
    }
}
