import CoreGraphics

/// The overlay's column split and panel size for a screen.
///
/// Rows and section titles have fixed heights, so everything is computed
/// before rendering. Sections are separated by `sectionSpacing`; the last
/// section of a column has none below it.
public enum PanelLayout {
    /// Fixed sizes of the overlay, in points.
    public struct Metrics: Sendable {
        public static let standard = Self(
            padding: 20,
            headerHeight: 40,
            dividerHeight: 1,
            columnWidth: 260,
            columnSpacing: 24,
            rowHeight: 20,
            sectionTitleHeight: 24,
            sectionSpacing: 14,
            screenFraction: 0.9
        )

        public let padding: Double
        public let headerHeight: Double
        /// The divider below the header.
        public let dividerHeight: Double
        public let columnWidth: Double
        public let columnSpacing: Double
        public let rowHeight: Double
        public let sectionTitleHeight: Double
        /// Between sections, and between the divider and the first section.
        public let sectionSpacing: Double
        /// Share of the screen's visible area the overlay may cover.
        public let screenFraction: Double

        public init(
            padding: Double,
            headerHeight: Double,
            dividerHeight: Double,
            columnWidth: Double,
            columnSpacing: Double,
            rowHeight: Double,
            sectionTitleHeight: Double,
            sectionSpacing: Double,
            screenFraction: Double
        ) {
            self.padding = padding
            self.headerHeight = headerHeight
            self.dividerHeight = dividerHeight
            self.columnWidth = columnWidth
            self.columnSpacing = columnSpacing
            self.rowHeight = rowHeight
            self.sectionTitleHeight = sectionTitleHeight
            self.sectionSpacing = sectionSpacing
            self.screenFraction = screenFraction
        }

        /// Everything around the columns: padding, header, divider and the
        /// spacing above the first section.
        var chromeHeight: Double {
            padding * 2 + headerHeight + dividerHeight + sectionSpacing
        }
    }

    public struct Result: Equatable, Sendable {
        /// Section indices per column; see `ColumnLayout`.
        public let columns: [[Int]]
        public let size: CGSize
        /// True when the columns are taller than the panel can be.
        public let scrolls: Bool
    }

    /// The layout for sections with `rowCounts` rows on a screen whose
    /// visible area is `visible`.
    public static func layout(rowCounts: [Int], metrics: Metrics, visible: CGSize) -> Result {
        let maxWidth = visible.width * metrics.screenFraction - metrics.padding * 2
        let maxHeight = visible.height * metrics.screenFraction - metrics.chromeHeight
        // Each section counts the spacing below it, so one spacing is added
        // to the limit and taken off the result for the last section.
        let spacing = Int(metrics.sectionSpacing)
        let heights = rowCounts.map { rows in
            Int(metrics.sectionTitleHeight + Double(rows) * metrics.rowHeight) + spacing
        }
        let maxColumns = ColumnLayout.columnCount(
            availableWidth: maxWidth,
            columnWidth: metrics.columnWidth,
            spacing: metrics.columnSpacing
        )
        let columns = ColumnLayout.layout(heights, maxColumns: maxColumns, maxHeight: Int(maxHeight) + spacing)
        let tallest = Double(max((columns.map { ColumnLayout.height(of: $0, in: heights) }.max() ?? 0) - spacing, 0))
        let count = Double(max(columns.count, 1))
        let size = CGSize(
            width: count * metrics.columnWidth + (count - 1) * metrics.columnSpacing + metrics.padding * 2,
            height: max(min(tallest, maxHeight), 0) + metrics.chromeHeight
        )
        return Result(columns: columns, size: size, scrolls: tallest > maxHeight)
    }
}
