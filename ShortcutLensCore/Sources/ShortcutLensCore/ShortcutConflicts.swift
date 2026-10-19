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
    /// input order. Entries without a combo clash with nothing, and an entry
    /// at the same location is the same item listed twice, not a clash.
    public static func clashes(among entries: [Entry]) -> [[String]] {
        let byCombo = Dictionary(grouping: entries.filter { $0.combo != nil }) { $0.combo }
        return entries.map { entry in
            guard let combo = entry.combo, let group = byCombo[combo] else {
                return []
            }
            return group.map(\.location).filter { $0 != entry.location }
        }
    }

    /// The text shown under a conflicting row; nil without clashes.
    public static func explanation(for clashes: [String]) -> String? {
        clashes.isEmpty ? nil : "Also used by " + clashes.joined(separator: ", ")
    }
}
