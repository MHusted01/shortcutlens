/// The App Shortcuts that apply to one app: the global entries merged with the
/// app's own, which win for the same menu item.
///
/// AppKit already applies these to the app's menus, so the menu read reports
/// the custom keys. This only tells which items carry one, for the overlay's
/// marker.
public struct UserKeyEquivalents: Sendable {
    /// No App Shortcuts, e.g. when the setting is off or the store is empty.
    public static let empty = Self(global: [], app: [])

    /// A plain title and a menu path naming the same item are separate
    /// entries, just as they are separate keys in the store.
    private struct Target: Hashable {
        let title: String
        let menuPath: [String]?
    }

    private let entries: [Target: UserKeyEquivalent]

    public init(global: [UserKeyEquivalent], app: [UserKeyEquivalent]) {
        let pairs = (global + app).map { (Target(title: $0.title, menuPath: $0.menuPath), $0) }
        entries = Dictionary(pairs) { _, appEntry in appEntry }
    }

    public var isEmpty: Bool {
        entries.isEmpty
    }

    /// Whether an App Shortcut names this item and the item has its keys. An
    /// entry the app did not apply, e.g. one for a renamed item, matches
    /// nothing.
    public func isCustom(_ shortcut: MenuShortcut) -> Bool {
        let candidates = [
            entries[Target(title: shortcut.title, menuPath: shortcut.menuPath)],
            entries[Target(title: shortcut.title, menuPath: nil)],
        ]
        return candidates.contains { $0.map { Self.keys(of: $0, match: shortcut) } ?? false }
    }

    /// Items with a glyph are matched by modifiers alone: the store holds a
    /// function-key code there, which the menu reports as a glyph instead.
    private static func keys(of entry: UserKeyEquivalent, match shortcut: MenuShortcut) -> Bool {
        guard entry.modifiers == shortcut.modifiers else {
            return false
        }
        return shortcut.glyph != nil || shortcut.keyCharacter?.lowercased() == entry.key
    }
}
