import ShortcutLensCore
import Testing

struct ColumnLayoutTests {
    @Test func partitionsInOrderMinimisingTheTallestColumn() {
        let columns = ColumnLayout.partition([5, 1, 1, 1, 5, 3], into: 3)

        #expect(columns == [[0, 1, 2], [3, 4], [5]])
    }

    @Test func partitionKeepsEverySectionExactlyOnceInOrder() {
        let heights = [3, 9, 2, 7, 4, 4, 8, 1]

        let columns = ColumnLayout.partition(heights, into: 3)

        #expect(columns.count == 3)
        #expect(columns.flatMap(\.self) == Array(heights.indices))
        #expect(columns.map { ColumnLayout.height(of: $0, in: heights) }.max() == 13)
    }

    @Test func partitionNeverReturnsEmptyColumns() {
        let columns = ColumnLayout.partition([10, 1, 1], into: 3)

        #expect(columns == [[0], [1], [2]])
    }

    @Test func partitionClampsColumnCountToSectionCount() {
        #expect(ColumnLayout.partition([2, 2], into: 5) == [[0], [1]])
        #expect(ColumnLayout.partition([2, 2], into: 0) == [[0, 1]])
        #expect(ColumnLayout.partition([], into: 3).isEmpty)
    }

    @Test func layoutUsesFewestColumnsThatFit() {
        let columns = ColumnLayout.layout([4, 4, 4, 4], maxColumns: 4, maxHeight: 8)

        #expect(columns == [[0, 1], [2, 3]])
    }

    @Test func layoutUsesOneColumnWhenEverythingFits() {
        #expect(ColumnLayout.layout([1, 2, 3], maxColumns: 4, maxHeight: 100) == [[0, 1, 2]])
    }

    @Test func layoutFallsBackToMaxColumnsWhenNothingFits() {
        let columns = ColumnLayout.layout([9, 9, 9], maxColumns: 2, maxHeight: 5)

        #expect(columns.count == 2)
        #expect(columns.flatMap(\.self) == [0, 1, 2])
    }

    @Test func columnCountFitsTheWidth() {
        #expect(ColumnLayout.columnCount(availableWidth: 1000, columnWidth: 240, spacing: 20) == 3)
        #expect(ColumnLayout.columnCount(availableWidth: 1020, columnWidth: 240, spacing: 20) == 4)
        #expect(ColumnLayout.columnCount(availableWidth: 100, columnWidth: 240, spacing: 20) == 1)
    }
}
