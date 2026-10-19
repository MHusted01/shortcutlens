/// The key and modifier names a pack file may use.
enum PackKeys {
    /// Names for keys that have no single printable character, mapped to the
    /// symbol `MenuGlyph` displays for them. `F1`...`F19` are their own symbols.
    private static let namedKeySymbols: [String: String] = [
        "Space": "Space",
        "Return": "↩",
        "Enter": "⌤",
        "Tab": "⇥",
        "Escape": "⎋",
        "Delete": "⌫",
        "ForwardDelete": "⌦",
        "Clear": "⌧",
        "PageUp": "⇞",
        "PageDown": "⇟",
        "Home": "↖",
        "End": "↘",
        "Left": "←",
        "Right": "→",
        "Up": "↑",
        "Down": "↓",
        "Help": "Help",
    ]

    /// `command` maps to `.noCommand`, which the caller removes instead of adding.
    private static let modifiers: [String: ModifierMask] = [
        "control": .control,
        "option": .option,
        "shift": .shift,
        "command": .noCommand,
    ]

    static func modifier(named name: String) -> ModifierMask? {
        modifiers[name]
    }

    /// A key name becomes a glyph, a single character stays a character.
    /// Nil when the key is neither, or would not display.
    static func shortcut(title: String, key: String, modifiers: ModifierMask, menuPath: [String]) -> MenuShortcut? {
        let shortcut: MenuShortcut
        if key.count == 1 {
            shortcut = MenuShortcut(title: title, keyCharacter: key, modifiers: modifiers, menuPath: menuPath)
        } else if let glyph = MenuGlyph.code(for: namedKeySymbols[key] ?? key) {
            shortcut = MenuShortcut(
                title: title, keyCharacter: nil, modifiers: modifiers, glyph: glyph, menuPath: menuPath
            )
        } else {
            return nil
        }
        return ShortcutFormatter.keySymbol(for: shortcut) == nil ? nil : shortcut
    }
}
