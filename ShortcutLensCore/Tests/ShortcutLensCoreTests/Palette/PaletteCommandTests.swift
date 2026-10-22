import ShortcutLensCore
import Testing

struct PaletteCommandTests {
    typealias State = PaletteState<Int>
    typealias RowID = PaletteState<Int>.RowID

    /// File: Save, Open (disabled), Print (display-only); Edit: Copy.
    private static let content = OverlayContent(appName: "App", sections: [
        OverlaySection(id: 0, title: "File", rows: [
            OverlayRow(id: 0, title: "Save", keys: "⌘S", element: 0),
            OverlayRow(id: 1, title: "Open", keys: "⌘O", isEnabled: false, element: 1),
            OverlayRow(id: 2, title: "Print", keys: "⌘P", element: nil),
        ]),
        OverlaySection(id: 1, title: "Edit", rows: [
            OverlayRow(id: 0, title: "Copy", keys: "⌘C", element: 10),
        ]),
    ])

    private static let loaded = State().with(content: content)
    private static let twoColumns = [[0], [1]]

    private static func respond(
        _ state: State, to command: SearchCommand, columns: [[Int]]? = twoColumns
    ) -> State.CommandResponse {
        state.responding(to: command, columns: columns, metrics: .standard)
    }

    /// The state after `command`, or nil when the response is not an update.
    private static func updated(_ state: State, by command: SearchCommand, columns: [[Int]]? = twoColumns) -> State? {
        guard case let .updated(next) = respond(state, to: command, columns: columns) else {
            return nil
        }
        return next
    }

    @Test func downAndUpMoveTheSelectionAndWrap() {
        #expect(Self.updated(Self.loaded, by: .moveDown)?.selection == RowID(section: 0, row: 1))
        #expect(Self.updated(Self.loaded, by: .moveUp)?.selection == RowID(section: 1, row: 0))
    }

    @Test func rightMovesToTheNextColumn() {
        #expect(Self.updated(Self.loaded, by: .moveRight)?.selection == RowID(section: 1, row: 0))
    }

    @Test func leftAndRightAreUnhandledWithoutColumns() {
        guard case .unhandled = Self.respond(Self.loaded, to: .moveLeft, columns: nil) else {
            Issue.record("expected unhandled")
            return
        }
    }

    @Test func leftAndRightAreUnhandledWhenTheSelectionStays() {
        guard case .unhandled = Self.respond(Self.loaded, to: .moveRight, columns: [[0, 1]]) else {
            Issue.record("expected unhandled")
            return
        }
    }

    @Test func returnRunsTheSelectedRow() {
        guard case let .run(row) = Self.respond(Self.loaded, to: .submit) else {
            Issue.record("expected run")
            return
        }
        #expect(row.element == 0)
    }

    @Test func returnRefusesARowThatCannotRun() {
        let disabled = Self.loaded.movingSelection(by: 1)
        let displayOnly = Self.loaded.movingSelection(by: 2)

        for state in [disabled, displayOnly, State()] {
            guard case .refused = Self.respond(state, to: .submit) else {
                Issue.record("expected refused")
                return
            }
        }
    }

    @Test func escapeClearsTheQueryFirst() {
        let state = Self.updated(Self.loaded.with(query: "co"), by: .cancel)

        #expect(state?.query == "")
        #expect(state?.visible?.rowCount == 4)
    }

    @Test func escapeOnAnEmptyQueryCloses() {
        guard case .close = Self.respond(Self.loaded, to: .cancel) else {
            Issue.record("expected close")
            return
        }
    }
}
