/// Splits the overlay's sections into columns. Sections keep their menu bar
/// order and are never split; columns are filled top to bottom, left to
/// right, like a newspaper.
///
/// Heights are in whole points, so the search below stays exact.
public enum ColumnLayout {
    /// The fewest columns, up to `maxColumns`, whose tallest column fits in
    /// `maxHeight`. When no count fits, `maxColumns` columns (the view then
    /// scrolls). Each column lists section indices.
    public static func layout(_ heights: [Int], maxColumns: Int, maxHeight: Int) -> [[Int]] {
        let limit = min(max(maxColumns, 1), max(heights.count, 1))
        for count in 1 ... limit {
            let columns = partition(heights, into: count)
            if tallest(columns, in: heights) <= maxHeight {
                return columns
            }
        }
        return partition(heights, into: limit)
    }

    /// Exactly `count` non-empty columns (clamped to 1 ... sections) whose
    /// tallest column is as short as possible.
    public static func partition(_ heights: [Int], into count: Int) -> [[Int]] {
        guard !heights.isEmpty else {
            return []
        }
        let count = min(max(count, 1), heights.count)
        // Binary search for the smallest column height that `count` columns can hold.
        var low = heights.max() ?? 0
        var high = heights.reduce(0, +)
        while low < high {
            let middle = (low + high) / 2
            if fill(heights, count: count, limit: middle).count <= count {
                high = middle
            } else {
                low = middle + 1
            }
        }
        return fill(heights, count: count, limit: low)
    }

    /// The summed height of the sections in `column`.
    public static func height(of column: [Int], in heights: [Int]) -> Int {
        column.reduce(0) { $0 + heights[$1] }
    }

    /// How many columns of `columnWidth` fit side by side, at least one.
    public static func columnCount(availableWidth: Double, columnWidth: Double, spacing: Double) -> Int {
        max(Int((availableWidth + spacing) / (columnWidth + spacing)), 1)
    }

    private static func tallest(_ columns: [[Int]], in heights: [Int]) -> Int {
        columns.map { height(of: $0, in: heights) }.max() ?? 0
    }

    /// Greedy fill up to `limit` per column. Starts a new column early once
    /// the sections left are just enough to give each remaining column one,
    /// so the result has `count` columns whenever `limit` allows it.
    private static func fill(_ heights: [Int], count: Int, limit: Int) -> [[Int]] {
        var columns: [[Int]] = []
        var current: [Int] = []
        var currentHeight = 0
        for index in heights.indices {
            let columnsStillNeeded = count - columns.count - 1
            let sectionsLeft = heights.count - index
            let overflows = currentHeight + heights[index] > limit
            if !current.isEmpty, overflows || sectionsLeft <= columnsStillNeeded {
                columns.append(current)
                current = []
                currentHeight = 0
            }
            current.append(index)
            currentHeight += heights[index]
        }
        return columns + [current]
    }
}
