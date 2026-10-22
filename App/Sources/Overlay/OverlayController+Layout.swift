import AppKit
import ShortcutLensCore

extension OverlayController {
    private static let placeholderSize = CGSize(width: 360, height: 150)

    /// Shows the panel with the current content. With `prepareOnly` it lays
    /// the content out in the hidden panel instead: building the views for a
    /// large menu takes most of the time to show it, and done during the
    /// countdown, the show that follows only applies what changed since.
    func render(prepareOnly: Bool = false) {
        guard let target, let visible = Self.visibleFrameUnderPointer() else {
            return
        }
        Self.measured(prepareOnly ? "prerender" : "render", rows: content?.rowCount ?? 0) {
            let (body, size) = Self.layout(content, in: visible)
            let view = OverlayView(
                appName: target.name, icon: target.icon, content: body,
                onSelect: { [weak self] row in self?.run(row) },
                onEdit: { [weak self] id, row in self?.edit(row, id: id) },
                onFavourite: favouriteHandler
            )
            let frame = ScreenPicker.centeredFrame(size: size, in: visible)
            if prepareOnly {
                panel.prepare(view, frame: frame)
            } else {
                panel.present(view, frame: frame)
            }
        }
    }

    /// The visible frame (without menu bar and Dock) of the screen under the pointer.
    static func visibleFrameUnderPointer() -> CGRect? {
        let screens = NSScreen.screens
        let index = ScreenPicker.index(for: NSEvent.mouseLocation, in: screens.map(\.frame))
        return (index.map { screens[$0] } ?? NSScreen.main)?.visibleFrame
    }

    /// The body to show and the panel size it needs on a screen whose visible
    /// area is `visible`. Nil `content` means the read is still running.
    static func layout(_ content: OverlayContent<AXUIElement>?, in visible: CGRect) -> (OverlayBody, CGSize) {
        guard let content else {
            return (.loading, placeholderSize)
        }
        guard !content.isEmpty else {
            return (.empty, placeholderSize)
        }
        let result = PanelLayout.layout(
            lineCounts: content.sections.map(\.lineCount),
            metrics: .standard,
            visible: visible.size
        )
        return (.shortcuts(sections: content.sections, columns: result.columns, scrolls: result.scrolls), result.size)
    }

    /// The palette's visible rows laid out inside the panel `size` that the
    /// `unfiltered` body needs. Loading and empty states are kept as they are.
    static func paletteBody(_ state: PaletteState<AXUIElement>, unfiltered: OverlayBody, size: CGSize) -> OverlayBody {
        guard case .shortcuts = unfiltered, let visible = state.visible else {
            return unfiltered
        }
        guard !visible.isEmpty else {
            return .noMatches
        }
        let result = PanelLayout.layout(
            lineCounts: visible.sections.map(\.lineCount),
            metrics: .standard,
            fitting: size
        )
        return .shortcuts(sections: visible.sections, columns: result.columns, scrolls: result.scrolls)
    }
}
