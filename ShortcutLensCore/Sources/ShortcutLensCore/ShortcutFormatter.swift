/// Renders shortcuts the way macOS menus display them, e.g. `⌃⌥⇧⌘S`.
public enum ShortcutFormatter {
    /// Modifier symbols in Apple HIG order: Control, Option, Shift, Command.
    public static func modifierSymbols(for modifiers: ModifierMask) -> String {
        let prefix = orderedModifiers
            .filter { modifiers.contains($0.modifier) }
            .map(\.symbol)
            .joined()
        return modifiers.includesCommand ? prefix + "⌘" : prefix
    }

    private static let orderedModifiers: [(modifier: ModifierMask, symbol: String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
    ]

    /// The key part of the shortcut. A known glyph wins over the character,
    /// because function keys report private-use characters. Returns nil when
    /// neither yields something displayable.
    public static func keySymbol(for shortcut: MenuShortcut) -> String? {
        if let glyph = shortcut.glyph, let symbol = MenuGlyph.symbol(for: glyph) {
            return symbol
        }
        guard let character = shortcut.keyCharacter, !character.isEmpty else {
            return nil
        }
        return character.uppercased()
    }

    /// The full display string, or nil when the item has no usable key.
    public static func string(for shortcut: MenuShortcut) -> String? {
        keySymbol(for: shortcut).map { modifierSymbols(for: shortcut.modifiers) + $0 }
    }
}
