import AppKit
import ShortcutLensCore

/// "Edit Shortcut…" from a row's context menu.
extension OverlayController {
    /// Closes the panel and hands the row to the shortcut editor, with the
    /// content shown, so the editor can check the new keys against it.
    func edit(_ row: OverlayRow<AXUIElement>, id: RowID) {
        guard let target, let content, row.element != nil else {
            return
        }
        let request = ShortcutEditRequest(
            appName: target.name,
            processID: target.processID,
            bundleID: target.bundleID,
            bundleURL: target.bundleURL,
            isSandboxed: target.bundleURL.map(AppSandbox.isSandboxed(bundleURL:)) ?? false,
            title: row.title,
            menuPath: row.menuPath,
            currentKeys: row.keys,
            row: id,
            content: content
        )
        if isPaletteOpen {
            onClosePalette()
        } else {
            hide()
        }
        onEditShortcut(request)
    }
}
