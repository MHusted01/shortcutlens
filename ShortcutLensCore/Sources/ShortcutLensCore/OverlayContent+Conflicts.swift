extension OverlayContent {
    /// A copy whose rows explain which other rows use the same keys. A row is
    /// named by its section and title, as the overlay shows it, e.g.
    /// `System > Lock Screen`.
    func markingConflicts() -> Self {
        let entries = sections.flatMap { section in
            section.rows.map { ShortcutConflicts.Entry(combo: $0.combo, location: "\(section.title) > \($0.title)") }
        }
        var explanations = ShortcutConflicts.clashes(among: entries)
            .map(ShortcutConflicts.explanation(for:))
            .makeIterator()
        let marked = sections.map { section in
            OverlaySection(id: section.id, title: section.title, rows: section.rows.map { row in
                row.with(conflict: explanations.next() ?? nil)
            })
        }
        return Self(appName: appName, sections: marked)
    }
}
