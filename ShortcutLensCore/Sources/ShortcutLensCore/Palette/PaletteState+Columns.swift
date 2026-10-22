extension PaletteState {
    /// A visible row and its height in its column, from the column's top.
    private struct RowPosition {
        let id: RowID
        let height: Double
    }

    /// The selection moved `offset` columns to the right (negative: left),
    /// wrapping around, to the row nearest the same height in that column.
    /// On a tie the upper row wins. `columns` holds indices into
    /// `visible.sections`, as `PanelLayout` returns them; with one column or
    /// no selection nothing changes.
    public func movingSelection(columns offset: Int, in columns: [[Int]], metrics: PanelLayout.Metrics) -> Self {
        guard let selection, let sections = visible?.sections, columns.count > 1 else {
            return self
        }
        let positions = columns.map { Self.positions(of: $0, in: sections, metrics: metrics) }
        guard let current = positions.firstIndex(where: { $0.contains { $0.id == selection } }),
              let height = positions[current].first(where: { $0.id == selection })?.height
        else {
            return self
        }
        let count = columns.count
        let target = ((current + offset) % count + count) % count
        guard let nearest = positions[target].min(by: { abs($0.height - height) < abs($1.height - height) }) else {
            return self
        }
        return selecting(nearest.id)
    }

    /// The rows of the sections at `indices`, stacked as the overlay draws
    /// them; a row is `lineCount` row heights tall.
    private static func positions(
        of indices: [Int],
        in sections: [OverlaySection<Element>],
        metrics: PanelLayout.Metrics
    ) -> [RowPosition] {
        var top = 0.0
        return indices.filter(sections.indices.contains).flatMap { index in
            let section = sections[index]
            let rowsTop = top + metrics.sectionTitleHeight
            top = rowsTop + Double(section.lineCount) * metrics.rowHeight + metrics.sectionSpacing
            let linesAbove = section.rows.reduce(into: [0]) { $0.append($0[$0.count - 1] + $1.lineCount) }
            return zip(section.rows, linesAbove).map { row, lines in
                let height = rowsTop + Double(lines) * metrics.rowHeight
                return RowPosition(id: RowID(section: section.id, row: row.id), height: height)
            }
        }
    }
}
