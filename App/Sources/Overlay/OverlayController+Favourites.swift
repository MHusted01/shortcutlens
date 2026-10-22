import AppKit
import ShortcutLensCore

/// "Add to Favourites" / "Remove from Favourites" from a row's context menu.
extension OverlayController {
    /// The context menu action, or nil to hide it: favourites are stored by
    /// bundle ID, so an app without one cannot have any.
    var favouriteHandler: ((OverlayRow<AXUIElement>) -> Void)? {
        guard target?.bundleID != nil else {
            return nil
        }
        return { [weak self] row in self?.toggleFavourite(row) }
    }

    /// Adds the row's menu item to the target app's favourites, or removes
    /// it, saves them and shows the content again with the change.
    private func toggleFavourite(_ row: OverlayRow<AXUIElement>) {
        guard let target, let bundleID = target.bundleID, let content, row.canBeFavourite else {
            return
        }
        favourites = favourites.toggling(row.menuPath, bundleID: bundleID)
        favourites.save(to: UserDefaults.standard)
        display(content.pinning(favourites.paths(for: bundleID)))
    }
}
