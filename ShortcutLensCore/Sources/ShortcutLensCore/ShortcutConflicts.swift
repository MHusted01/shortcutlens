/// Finds key combinations that more than one shortcut uses, within an app or
/// between an app and the system.
///
/// Disabled menu items count: they still own their keys, and an app that
/// enables one of two items on the same keys can run either.
public enum ShortcutConflicts {
    /// A shortcut and where it is listed, e.g. `File > Close`.
    public struct Entry: Sendable {
        public let combo: KeyCombo?
        public let location: String

        public init(combo: KeyCombo?, location: String) {
            self.combo = combo
            self.location = location
        }
    }

    /// For each entry, the locations of the other entries with its combo, in
    /// input order. Entries without a combo clash with nothing. Entries are
    /// told apart by position, so two items with the same title still clash.
    public static func clashes(among entries: [Entry]) -> [[String]] {
        let indexed = entries.enumerated().filter { $0.element.combo != nil }
        let byCombo = Dictionary(grouping: indexed) { $0.element.combo }
        return entries.enumerated().map { index, entry in
            guard let combo = entry.combo, let group = byCombo[combo] else {
                return []
            }
            return group.filter { $0.offset != index }.map(\.element.location)
        }
    }

    /// The text shown under a conflicting row; nil without clashes.
    public static func explanation(for clashes: [String]) -> String? {
        clashes.isEmpty ? nil : "Also used by " + clashes.joined(separator: ", ")
    }
}
