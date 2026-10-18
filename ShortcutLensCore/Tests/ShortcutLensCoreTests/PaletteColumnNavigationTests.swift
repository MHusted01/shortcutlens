import ShortcutLensCore
import Testing

struct PaletteColumnNavigationTests {
    typealias State = PaletteState<Int>

    /// Round numbers: title 20, row 10, spacing 10. A row's height in its
    /// column is the sections above it, plus its title, plus the rows above.
    private static let metrics = PanelLayout.Metrics(
        padding: 10,
        headerHeight: 30,
        dividerHeight: 0,
        columnWidth: 100,
        columnSpacing: 20,
        rowHeight: 10,
        sectionTitleHeight: 20,
        sectionSpacing: 10,
        screenFraction: 1
    )

    /// File: a b c (heights 20 30 40); Edit: d e (80 90 below File);
    /// View: f g h i (20 30 40 50 at the top of a column).
    private static let content = OverlayContent(appName: "App", sections: [
        section(id: 0, "File", ["a", "b", "c"]),
        section(id: 1, "Edit", ["d", "e"]),
        section(id: 2, "View", ["f", "g", "h", "i"]),
    ])

    private static func section(id: Int, _ title: String, _ rows: [String]) -> OverlaySection<Int> {
        OverlaySection(id: id, title: title, rows: rows.enumerated().map { index, title in
            OverlayRow(id: index, title: title, keys: "⌘X", element: id * 10 + index)
        })
    }

    /// The state with `title` selected, reached with Down from the first row.
    private static func selected(_ title: String, query: String = "") -> State {
        var state = State().with(content: content).with(query: query)
        for _ in 0 ..< 20 where state.selectedRow?.title != title {
            state = state.movingSelection(by: 1)
        }
        return state
    }

    private static func move(_ title: String, by offset: Int, columns: [[Int]]) -> String? {
        selected(title).movingSelection(columns: offset, in: columns, metrics: metrics).selectedRow?.title
    }

    @Test func rightKeepsTheHeight() {
        #expect(Self.move("b", by: 1, columns: [[0, 1], [2]]) == "g")
        #expect(Self.move("a", by: 1, columns: [[0, 1], [2]]) == "f")
    }

    @Test func picksTheNearestRowWhenTheTargetColumnIsShorter() {
        #expect(Self.move("e", by: 1, columns: [[0, 1], [2]]) == "i")
    }

    @Test func leftPicksTheNearestRow() {
        #expect(Self.move("i", by: -1, columns: [[0, 1], [2]]) == "c")
        #expect(Self.move("h", by: -1, columns: [[0, 1], [2]]) == "c")
    }

    @Test func wrapsAroundBothWays() {
        let columns = [[0], [1], [2]]

        #expect(Self.move("f", by: 1, columns: columns) == "a")
        #expect(Self.move("b", by: -1, columns: columns) == "g")
    }

    @Test func singleColumnChangesNothing() {
        #expect(Self.move("b", by: 1, columns: [[0, 1, 2]]) == "b")
    }

    @Test func noSelectionChangesNothing() {
        let state = State().with(content: Self.content).with(query: "xyz")

        let moved = state.movingSelection(columns: 1, in: [[0], [1]], metrics: Self.metrics)

        #expect(moved.selection == nil)
    }

    /// "e" matches every section title, and the row "e" directly, so Edit
    /// lists e before d. The columns index the filtered sections.
    @Test func worksOnFilteredContent() {
        let state = State().with(content: Self.content).with(query: "e")
        let columns = [[0], [1], [2]]
        let atE = state.movingSelection(by: 3)

        let rows = state.visible?.sections.map { $0.rows.map(\.title) }
        #expect(rows == [["a", "b", "c"], ["e", "d"], ["f", "g", "h", "i"]])
        #expect(atE.selectedRow?.title == "e")
        let right = atE.movingSelection(columns: 1, in: columns, metrics: Self.metrics)
        #expect(right.selectedRow?.title == "f")
        let back = right.movingSelection(by: 1).movingSelection(columns: -1, in: columns, metrics: Self.metrics)
        #expect(back.selectedRow?.title == "d")
    }

    // MARK: - Defensive cases

    @Test func offsetsBeyondTheColumnCountWrap() {
        let columns = [[0], [1], [2]]

        #expect(Self.move("a", by: 3, columns: columns) == "a")
        #expect(Self.move("a", by: 4, columns: columns) == "d")
        #expect(Self.move("a", by: -4, columns: columns) == "f")
    }

    @Test func outOfRangeSectionIndicesAreSkipped() {
        #expect(Self.move("b", by: 1, columns: [[0, 7], [-1, 2]]) == "g")
    }

    @Test func selectionOutsideEveryColumnChangesNothing() {
        #expect(Self.move("b", by: 1, columns: [[1], [2]]) == "b")
    }

    @Test func emptyTargetColumnChangesNothing() {
        #expect(Self.move("b", by: 1, columns: [[0], []]) == "b")
    }
}
