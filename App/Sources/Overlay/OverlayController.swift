import AppKit
import ShortcutLensCore
import SwiftUI

/// Shows the frontmost app's shortcuts in `OverlayPanel`, as the hold-Command
/// overlay or as the palette; clicking an entry runs that menu item.
///
/// The controller coordinates: `OverlayContentLoader` reads and caches the
/// menus, `PaletteController` runs the palette, and `OverlayLayout` sizes the
/// panel. `prepare()` runs when the hold-Command countdown starts, so by the
/// time `show()` runs a second later the content is usually ready. Without
/// cached content the panel shows a loading state and fills in when the read
/// finishes.
///
/// Every way of closing the palette goes through `onClosePalette`, so the
/// trigger state machine always knows. Favourites are pinned as a first
/// section when content is shown and again when one is toggled.
@MainActor
final class OverlayController {
    /// The app the panel is for.
    struct Target {
        let name: String
        let processID: pid_t
        let bundleID: String?
        let bundleURL: URL?
        let icon: NSImage?
    }

    /// Called when the palette should close: Escape on an empty query, an
    /// item was run, or the panel lost key status.
    var onClosePalette: () -> Void = {}
    /// Called with the menu item the user chose "Edit Shortcut…" for, after
    /// the panel closed.
    var onEditShortcut: (ShortcutEditRequest) -> Void = { _ in }
    /// Whether a hold-Command countdown is running. A read that finishes
    /// during it lays the panel out ahead of time, so showing it is quick.
    var isCountingDown: () -> Bool = { false }

    let panels = OverlayPanelHost()
    let palette: PaletteController
    private let loader = OverlayContentLoader()
    private(set) var target: Target?
    private(set) var content: OverlayContent<AXUIElement>?
    private var isShown = false
    /// Changed by `toggleFavourite(_:)`.
    var favourites = Favourites(store: UserDefaults.standard)

    init() {
        palette = PaletteController(panels: panels)
        panels.onResignKey = { [weak self] in self?.onClosePalette() }
        palette.onClose = { [weak self] in self?.onClosePalette() }
        palette.onRun = { [weak self] row in self?.runFromPalette(row) }
        loader.onContent = { [weak self] content in
            guard let self else {
                return
            }
            display(pinned(content))
        }
    }

    /// Uses `settings` from the next menu read on.
    func apply(_ settings: AppSettings) {
        loader.apply(settings)
    }

    /// Drops system shortcuts labelled for the previous layout. An open panel
    /// or palette drops the old system section at once and shows the new one
    /// when the read finishes.
    func keyboardLayoutChanged() {
        guard loader.keyboardLayoutChanged(), isShown || palette.isOpen, target != nil else {
            return
        }
        if let cached = loader.reload() {
            display(pinned(cached))
        }
    }

    /// Starts reading the frontmost app's menus and shows its cached content
    /// until the read finishes. ShortcutLens itself is skipped.
    func prepare() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let app = frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : frontmost
        target = app.map {
            Target(
                name: $0.localizedName ?? "", processID: $0.processIdentifier, bundleID: $0.bundleIdentifier,
                bundleURL: $0.bundleURL, icon: $0.icon
            )
        }
        content = loader.load(app).map(pinned)
    }

    /// Shows the panel for the app `prepare()` captured.
    func show() {
        guard target != nil else {
            return
        }
        isShown = true
        render()
    }

    /// Shows the panel as a palette that takes typed keys. Closes the palette
    /// again when there is nothing to show it for.
    func showPalette() {
        guard let target else {
            onClosePalette()
            return
        }
        let shown = palette.show(content) { model in
            OverlayView(
                appName: target.name, icon: target.icon, content: .loading, palette: model,
                onSelect: { [weak self] row in self?.runFromPalette(row) },
                onEdit: { [weak self] id, row in self?.edit(row, id: id) },
                onFavourite: favouriteHandler
            )
        }
        guard shown else {
            onClosePalette()
            return
        }
        isShown = true
    }

    func hide(animated: Bool = false) {
        isShown = false
        palette.close()
        panels.panel.dismiss(animated: animated)
    }

    private func runFromPalette(_ row: OverlayRow<AXUIElement>) {
        onClosePalette()
        run(row)
    }

    /// Makes `content` the shown content and updates an open panel or palette.
    func display(_ content: OverlayContent<AXUIElement>) {
        self.content = content
        if palette.isOpen {
            palette.display(content)
        } else if isShown {
            render()
        } else if isCountingDown() {
            render(prepareOnly: true)
        }
    }

    /// Shows the panel with the current content. With `prepareOnly` it lays
    /// the content out in the hidden panel instead: building the views for a
    /// large menu takes most of the time to show it, and done during the
    /// countdown, the show that follows only applies what changed since.
    private func render(prepareOnly: Bool = false) {
        guard let target, let visible = OverlayLayout.visibleFrameUnderPointer() else {
            return
        }
        OverlayLog.measured(prepareOnly ? "prerender" : "render", rows: content?.rowCount ?? 0) {
            let (body, size) = OverlayLayout.layout(content, in: visible)
            let view = OverlayView(
                appName: target.name, icon: target.icon, content: body,
                onSelect: { [weak self] row in self?.run(row) },
                onEdit: { [weak self] id, row in self?.edit(row, id: id) },
                onFavourite: favouriteHandler
            )
            let frame = ScreenPicker.centeredFrame(size: size, in: visible)
            if prepareOnly {
                panels.panel.prepare(view, frame: frame)
            } else {
                panels.present(view, frame: frame)
            }
        }
    }

    /// `content` with the target app's favourites pinned before it.
    private func pinned(_ content: OverlayContent<AXUIElement>) -> OverlayContent<AXUIElement> {
        content.pinning(favourites.paths(for: target?.bundleID))
    }
}
