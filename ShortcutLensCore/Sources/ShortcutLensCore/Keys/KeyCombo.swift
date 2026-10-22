/// The keys a shortcut is pressed with, comparable across menu items and
/// system shortcuts.
///
/// The key is the symbol the overlay displays, so a key reported as a
/// character (" ") and as a glyph (Space) is the same key, and case does not
/// matter. Modifiers must match exactly.
public struct KeyCombo: Hashable, Sendable {
    /// The displayed key symbol, e.g. `S` or `Space`.
    public let key: String
    public let modifiers: ModifierMask

    public init(key: String, modifiers: ModifierMask) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Nil when the shortcut has no displayable key.
    public init?(_ shortcut: MenuShortcut) {
        guard let key = ShortcutFormatter.keySymbol(for: shortcut) else {
            return nil
        }
        self.init(key: key, modifiers: shortcut.modifiers)
    }
}
