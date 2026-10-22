public extension PaletteState {
    /// What the palette does with a `SearchCommand`.
    enum CommandResponse {
        /// Show the new state.
        case updated(PaletteState<Element>)
        /// Left/Right without another column to move to: the search field
        /// moves its cursor instead.
        case unhandled
        /// Run the row and close the palette.
        case run(OverlayRow<Element>)
        /// Return without a row that can run.
        case refused
        case close
    }

    /// The response to `command`. `columns` are the columns shown, as
    /// `PanelLayout` returns them; nil when no rows are shown.
    func responding(
        to command: SearchCommand, columns: [[Int]]?, metrics: PanelLayout.Metrics
    ) -> CommandResponse {
        switch command {
        case .moveUp:
            .updated(movingSelection(by: -1))
        case .moveDown:
            .updated(movingSelection(by: 1))
        case .moveLeft:
            movingColumn(by: -1, in: columns, metrics: metrics)
        case .moveRight:
            movingColumn(by: 1, in: columns, metrics: metrics)
        case .submit:
            selectedRow.flatMap { $0.isRunnable ? .run($0) : nil } ?? .refused
        case .cancel:
            switch escaped() {
            case let .cleared(state):
                .updated(state)
            case .close:
                .close
            }
        }
    }

    private func movingColumn(by offset: Int, in columns: [[Int]]?, metrics: PanelLayout.Metrics) -> CommandResponse {
        guard let columns else {
            return .unhandled
        }
        let moved = movingSelection(columns: offset, in: columns, metrics: metrics)
        return moved.selection == selection ? .unhandled : .updated(moved)
    }
}
