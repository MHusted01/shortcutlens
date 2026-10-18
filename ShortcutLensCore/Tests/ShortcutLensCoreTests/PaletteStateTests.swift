import ShortcutLensCore
import Testing

struct PaletteStateTests {
    typealias State = PaletteState<Int>
    typealias RowID = PaletteState<Int>.RowID

    /// File: Save, Save As…, Open (elements 0-2); Edit: Copy, Paste (elements 10-11).
    private static let content = OverlayContent(appName: "App", sections: [
        OverlaySection(id: 0, title: "File", rows: [
            OverlayRow(id: 0, title: "Save", keys: "⌘S", element: 0),
            OverlayRow(id: 1, title: "Save As…", keys: "⇧⌘S", element: 1),
            OverlayRow(id: 2, title: "Open", keys: "⌘O", element: 2),
        ]),
        OverlaySection(id: 1, title: "Edit", rows: [
            OverlayRow(id: 0, title: "Copy", keys: "⌘C", element: 10),
            OverlayRow(id: 1, title: "Paste", keys: "⌘V", element: 11),
        ]),
    ])

    private static let loaded = State().with(content: content)

    @Test func startsLoadingWithoutSelection() {
        let state = State()

        #expect(state.query.isEmpty)
        #expect(state.visible == nil)
        #expect(state.selection == nil)
        #expect(state.selectedRow == nil)
    }

    @Test func contentSelectsFirstRow() {
        #expect(Self.loaded.selection == RowID(section: 0, row: 0))
        #expect(Self.loaded.selectedRow?.element == 0)
        #expect(Self.loaded.visible?.rowCount == 5)
    }

    @Test func queryFiltersAndSelectsFirstMatch() {
        let state = Self.loaded.with(query: "pa")

        #expect(state.query == "pa")
        #expect(state.visible?.sections.map(\.title) == ["Edit"])
        #expect(state.selection == RowID(section: 1, row: 1))
        #expect(state.selectedRow?.element == 11)
    }

    @Test func queryChangeResetsSelectionToFirstMatch() {
        let moved = Self.loaded.movingSelection(by: 2)

        let state = moved.with(query: "s")

        #expect(state.selectedRow?.title == "Save")
    }

    @Test func queryTypedWhileLoadingAppliesWhenContentArrives() {
        let state = State().with(query: "copy").with(content: Self.content)

        #expect(state.visible?.rowCount == 1)
        #expect(state.selectedRow?.element == 10)
    }

    @Test func noMatchesMeansNoSelection() {
        let state = Self.loaded.with(query: "xyz")

        #expect(state.visible?.isEmpty == true)
        #expect(state.selection == nil)
        #expect(state.selectedRow == nil)
        #expect(state.movingSelection(by: 1).selection == nil)
    }

    @Test func downMovesThroughSectionsInDisplayOrder() {
        let titles = (0 ..< 5).map { Self.loaded.movingSelection(by: $0).selectedRow?.title }

        #expect(titles == ["Save", "Save As…", "Open", "Copy", "Paste"])
    }

    @Test func movingWrapsBothWays() {
        #expect(Self.loaded.movingSelection(by: -1).selectedRow?.title == "Paste")
        #expect(Self.loaded.movingSelection(by: 5).selectedRow?.title == "Save")
        #expect(Self.loaded.movingSelection(by: 4).movingSelection(by: 1).selectedRow?.title == "Save")
    }

    @Test func movingWithinFilteredRows() {
        let state = Self.loaded.with(query: "save")

        #expect(state.movingSelection(by: 1).selectedRow?.title == "Save As…")
        #expect(state.movingSelection(by: 2).selectedRow?.title == "Save")
    }

    @Test func newContentKeepsQueryAndReselects() {
        let state = Self.loaded.with(query: "open").with(content: Self.content)

        #expect(state.query == "open")
        #expect(state.selectedRow?.element == 2)
    }

    @Test(arguments: ["pa", "  "])
    func escapeClearsQueryFirst(query: String) {
        let outcome = Self.loaded.with(query: query).escaped()

        guard case let .cleared(state) = outcome else {
            Issue.record("expected cleared, got \(outcome)")
            return
        }
        #expect(state.query.isEmpty)
        #expect(state.visible?.rowCount == 5)
        #expect(state.selection == RowID(section: 0, row: 0))
    }

    @Test func escapeWithEmptyQueryCloses() {
        guard case .close = Self.loaded.escaped() else {
            Issue.record("expected close")
            return
        }
    }
}
