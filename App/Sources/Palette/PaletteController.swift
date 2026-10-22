import AppKit
import ShortcutLensCore

/// Shows the overlay's content as a command palette: typing filters, arrow
/// keys select, Return runs. The panel keeps the size it has for all rows
/// while filtering.
///
/// VoiceOver: the search field keeps keyboard focus while the arrow keys
/// move the selection, so VoiceOver would say nothing; every change is
/// announced instead (see `PaletteAnnouncement`). The hold-Command overlay
/// announces nothing: it cannot be navigated while Command is held.
@MainActor
final class PaletteController {
    /// The open palette and the screen area it was opened on.
    private struct OpenPalette {
        let state: PaletteState<AXUIElement>
        let model: PaletteModel
        let screen: CGRect

        func with(_ state: PaletteState<AXUIElement>) -> Self {
            Self(state: state, model: model, screen: screen)
        }
    }

    /// Called when the palette should close: Escape on an empty query.
    var onClose: () -> Void = {}
    /// Called with the row Return chose.
    var onRun: (OverlayRow<AXUIElement>) -> Void = { _ in }

    private let panel: OverlayPanel
    private var open: OpenPalette? {
        didSet { announce(from: oldValue?.state, to: open?.state) }
    }

    var isOpen: Bool {
        open != nil
    }

    init(panel: OverlayPanel) {
        self.panel = panel
    }

    /// Presents `content` (nil while the read runs) as a palette, in the view
    /// `makeView` builds around the palette's model, on the screen under the
    /// pointer. Returns false when there is no screen to show it on.
    func show(_ content: OverlayContent<AXUIElement>?, makeView: (PaletteModel) -> OverlayView) -> Bool {
        guard let screen = OverlayLayout.visibleFrameUnderPointer() else {
            return false
        }
        let model = PaletteModel(
            onQueryChange: { [weak self] query in self?.update { $0.with(query: query) } },
            onCommand: { [weak self] command in self?.handle(command) ?? false }
        )
        let state = content.map { PaletteState().with(content: $0) } ?? PaletteState()
        open = OpenPalette(state: state, model: model, screen: screen)
        let size = refresh()
        panel.present(makeView(model), frame: ScreenPicker.centeredFrame(size: size, in: screen), takesKeyboard: true)
        OverlayLog.logger.notice("palette shown")
        return true
    }

    /// Shows `content` with the current query, resizing the panel for it.
    func display(_ content: OverlayContent<AXUIElement>) {
        guard let open else {
            return
        }
        self.open = open.with(open.state.with(content: content))
        let size = refresh()
        panel.setFrame(ScreenPicker.centeredFrame(size: size, in: open.screen), display: true)
    }

    /// Forgets the palette; the caller hides the panel.
    func close() {
        open = nil
    }

    /// Returns false only for Left/Right without another column to move to,
    /// so the search field moves its cursor instead.
    private func handle(_ command: SearchCommand) -> Bool {
        guard let open else {
            return false
        }
        let columns: [[Int]]? = if case let .shortcuts(_, columns, _) = open.model.body {
            columns
        } else {
            nil
        }
        switch open.state.responding(to: command, columns: columns, metrics: .standard) {
        case let .updated(state):
            update { _ in state }
        case .unhandled:
            return false
        case let .run(row):
            onRun(row)
        case .refused:
            NSSound.beep()
        case .close:
            onClose()
        }
        return true
    }

    private func update(_ change: (PaletteState<AXUIElement>) -> PaletteState<AXUIElement>) {
        guard let open else {
            return
        }
        self.open = open.with(change(open.state))
        refresh()
    }

    /// Copies the palette state into the view model. Returns the panel size
    /// for all rows, which filtering does not change.
    @discardableResult
    private func refresh() -> CGSize {
        guard let open else {
            return .zero
        }
        let (body, size) = OverlayLayout.layout(open.state.content, in: open.screen)
        open.model.query = open.state.query
        open.model.selection = open.state.selection
        open.model.body = OverlayLayout.paletteBody(open.state, unfiltered: body, size: size)
        return size
    }

    /// Announces the change from `before` to `after`. Closing (`after` nil) is silent.
    private func announce(from before: PaletteState<AXUIElement>?, to after: PaletteState<AXUIElement>?) {
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
