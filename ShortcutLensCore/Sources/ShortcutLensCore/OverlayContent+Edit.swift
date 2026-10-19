public extension OverlayContent {
    /// The rows other than the edited one that already use `combo`, named like
    /// conflicts (`Section > Title`), in overlay order. Used to warn before an
    /// App Shortcut is saved; the edited row's current keys do not count.
    func clashes(with combo: KeyCombo, excludingSection section: Int, row: Int) -> [String] {
        sections.flatMap { candidate in
            candidate.rows
                .filter { $0.combo == combo && !(candidate.id == section && $0.id == row) }
                .map { "\(candidate.title) > \($0.title)" }
        }
    }
}
