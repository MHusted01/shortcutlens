extension OverlayContent {
    /// A copy whose rows explain which other rows use the same keys. A row is
    /// named by its section and display title, as the overlay shows it, e.g.
    /// `System > Lock Screen` or `Edit > Find > Find Next`.
    ///
    /// The Favourites section's copies are left out, so a row never clashes
    /// with its own copy; each copy shows its original's conflict instead.
    func markingConflicts() -> Self {
        let located = sections.enumerated().filter { !$0.element.isPinned }.flatMap { index, section in
            section.rows.map { (section: index, row: $0, location: "\(section.title) > \($0.displayTitle)") }
        }
        let clashes = ShortcutConflicts.clashes(among: located.map {
            ShortcutConflicts.Entry(combo: $0.row.combo, location: $0.location)
        })
        // `clashes` has one result per entry, so zip pairs each row with its own.
        let marked = Dictionary(grouping: zip(located, clashes)) { $0.0.section }
            .mapValues { $0.map { $0.0.row.with(conflict: ShortcutConflicts.explanation(for: $0.1)) } }
        let originals = marked.values.flatMap(\.self).filter(\.isFavourite)
        let rebuilt = sections.enumerated().map { index, section in
            let rows = section.isPinned
                ? section.rows.map { copy in
                    copy.with(conflict: originals.first { $0.menuPath == copy.menuPath }?.conflict)
                }
                : marked[index] ?? []
            return OverlaySection(id: section.id, title: section.title, rows: rows, isPinned: section.isPinned)
        }
        return Self(appName: appName, sections: rebuilt)
    }
}
