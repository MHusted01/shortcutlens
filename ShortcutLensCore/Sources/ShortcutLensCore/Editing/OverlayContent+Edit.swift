public extension OverlayContent {
    /// The rows other than the edited one that already use `combo`, named like
    /// conflicts (`Section > Title`) up to `ShortcutConflicts.shownLimit`, in
    /// overlay order, and counted in all. Used to warn before an
    /// App Shortcut is saved; the edited row's current keys do not count.
    /// Favourites are copies, so neither they nor the edited item's original
    /// or copy count either.
    func clashes(with combo: KeyCombo, excludingSection section: Int, row: Int) -> ShortcutConflicts.Clashes {
        let edited = sections.first { $0.id == section }?.rows.first { $0.id == row }
        let isEdited: (OverlayRow<Element>) -> Bool = { candidate in
            guard let edited, !edited.menuPath.isEmpty else {
                return false
            }
            return candidate.menuPath == edited.menuPath
        }
        let matches = sections.lazy.filter { !$0.isPinned }.flatMap { candidate in
            candidate.rows.lazy
                .filter { $0.combo == combo && !(candidate.id == section && $0.id == row) && !isEdited($0) }
                .map { (section: candidate.title, title: $0.displayTitle) }
        }
        let shown = matches.prefix(ShortcutConflicts.shownLimit)
            .map { ShortcutConflicts.location(section: $0.section, title: $0.title) }
        return ShortcutConflicts.Clashes(shown: Array(shown), total: matches.count)
    }
}
