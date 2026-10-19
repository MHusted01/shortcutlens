public extension OverlayContent {
    /// The rows other than the edited one that already use `combo`, named like
    /// conflicts (`Section > Title`), in overlay order. Used to warn before an
    /// App Shortcut is saved; the edited row's current keys do not count.
    /// Favourites are copies, so neither they nor the edited item's original
    /// or copy count either.
    func clashes(with combo: KeyCombo, excludingSection section: Int, row: Int) -> [String] {
        let edited = sections.first { $0.id == section }?.rows.first { $0.id == row }
        let isEdited: (OverlayRow<Element>) -> Bool = { candidate in
            guard let edited, !edited.menuPath.isEmpty else {
                return false
            }
            return candidate.menuPath == edited.menuPath
        }
        return sections.filter { !$0.isPinned }.flatMap { candidate in
            candidate.rows
                .filter { $0.combo == combo && !(candidate.id == section && $0.id == row) && !isEdited($0) }
                .map { "\(candidate.title) > \($0.title)" }
        }
    }
}
