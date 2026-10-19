extension OverlayContent {
    /// A copy whose rows explain which other rows use the same keys. A row is
    /// named by its section and title, as the overlay shows it, e.g.
    /// `System > Lock Screen`.
    func markingConflicts() -> Self {
        let located = sections.enumerated().flatMap { index, section in
            section.rows.map { (section: index, row: $0, location: "\(section.title) > \($0.title)") }
        }
        let clashes = ShortcutConflicts.clashes(among: located.map {
            ShortcutConflicts.Entry(combo: $0.row.combo, location: $0.location)
        })
        // `clashes` has one result per entry, so zip pairs each row with its own.
        let marked = Dictionary(grouping: zip(located, clashes)) { $0.0.section }
        let rebuilt = sections.enumerated().map { index, section in
            let rows = (marked[index] ?? []).map { $0.0.row.with(conflict: ShortcutConflicts.explanation(for: $0.1)) }
            return OverlaySection(id: section.id, title: section.title, rows: rows)
        }
        return Self(appName: appName, sections: rebuilt)
    }
}
