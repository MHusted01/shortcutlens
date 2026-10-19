import AppKit
import ShortcutLensCore

extension OverlayController {
    private static let placeholderSize = CGSize(width: 360, height: 150)

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
