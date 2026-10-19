/// Writing App Shortcuts: the inverse of `UserKeyEquivalent.init(title:keys:)`
/// and edits to an `NSUserKeyEquivalents` dictionary.
///
/// Edits always name the item by its menu path, so they change that one item
/// and not every item with the same title.
public extension UserKeyEquivalent {
    /// An entry for the item at `menuPath`; nil when the path or the key cannot
    /// be stored. An uppercase key is stored lowercase with Shift, as parsing
    /// would read it.
    init?(menuPath: [String], key: String, modifiers: ModifierMask) {
        guard !menuPath.contains(where: { $0.contains(Self.pathSeparator) }) else {
            return nil
        }
        self.init(title: Self.storeKey(for: menuPath), keys: Self.storeValue(key: key, modifiers: modifiers))
    }

    /// The dictionary key that names the item at `menuPath`.
    static func storeKey(for menuPath: [String]) -> String {
        menuPath.map { String(pathSeparator) + $0 }.joined()
    }

    /// This entry's dictionary key: its menu path, or its plain title.
    var storeKey: String {
        menuPath.map(Self.storeKey(for:)) ?? title
    }

    /// This entry's value, e.g. `"^~$@k"`: modifiers in Apple HIG order, then
    /// the key.
    var storeValue: String {
        Self.storeValue(key: key, modifiers: modifiers)
    }

    /// A copy of `dictionary` with `entry` set, replacing the item's previous
    /// entry; other entries are kept.
    static func setting(_ entry: Self, in dictionary: [String: Any]) -> [String: Any] {
        dictionary.merging([entry.storeKey: entry.storeValue]) { _, new in new }
    }

    /// A copy of `dictionary` without the entry for the item at `menuPath`. A
    /// plain-title entry is kept: it applies to other items too.
    static func removing(menuPath: [String], from dictionary: [String: Any]) -> [String: Any] {
        let key = storeKey(for: menuPath)
        return dictionary.filter { $0.key != key }
    }

    private static let storedModifiers: [(modifier: ModifierMask, character: String)] = [
        (.control, "^"), (.option, "~"), (.shift, "$"),
    ]

    private static func storeValue(key: String, modifiers: ModifierMask) -> String {
        let prefix = storedModifiers.filter { modifiers.contains($0.modifier) }.map(\.character).joined()
        return prefix + (modifiers.includesCommand ? "@" : "") + key
    }
}
