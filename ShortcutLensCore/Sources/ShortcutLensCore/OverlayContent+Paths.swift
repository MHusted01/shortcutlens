extension OverlayContent {
    /// A copy whose rows that share a title with another row of their section
    /// show their menu path instead, e.g. `Find > Find Next` next to
    /// `Spelling > Find Next`. The section header already names the top-level
    /// menu, so it is left out, except in Favourites, whose rows come from
    /// different menus and show the full path. Other rows show their title.
    ///
    /// Recomputed from `title` and `menuPath`, so it can be applied again.
    func disambiguatingTitles() -> Self {
        let sections = sections.map { section in
            let counts = Dictionary(section.rows.map { ($0.title, 1) }, uniquingKeysWith: +)
            let rows = section.rows.map { row in
                guard counts[row.title, default: 0] > 1 else {
                    return row.with(displayTitle: row.title)
                }
                return row.with(displayTitle: Self.pathTitle(of: row, in: section))
            }
            return OverlaySection(id: section.id, title: section.title, rows: rows, isPinned: section.isPinned)
        }
        return Self(appName: appName, sections: sections)
    }

    /// The row's path joined with ` > `, as conflicts name rows; the title
    /// when the row has no path below its section. The section's own title
    /// is left out only when the path starts with it.
    private static func pathTitle(of row: OverlayRow<Element>, in section: OverlaySection<Element>) -> String {
        let startsWithSection = !section.isPinned && row.menuPath.first == section.title
        let path = startsWithSection ? Array(row.menuPath.dropFirst()) : row.menuPath
        return path.isEmpty ? row.title : path.joined(separator: " > ")
    }
}
