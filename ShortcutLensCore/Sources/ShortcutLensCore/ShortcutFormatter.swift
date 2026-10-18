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

    /// The key part of the shortcut. A known glyph wins over the character,
    /// because function keys report private-use characters. Returns nil when
    /// neither yields something displayable.
    public static func keySymbol(for shortcut: MenuShortcut) -> String? {
        if let glyph = shortcut.glyph, let symbol = MenuGlyph.symbol(for: glyph) {
            return symbol
        }
        return shortcut.keyCharacter.flatMap(characterSymbol)
    }

    /// The full display string, or nil when the item has no usable key.
    public static func string(for shortcut: MenuShortcut) -> String? {
        keySymbol(for: shortcut).map { modifierSymbols(for: shortcut.modifiers) + $0 }
    }

    private static let orderedModifiers: [(modifier: ModifierMask, symbol: String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
    ]

    /// Keys that some apps report as a plain character instead of a glyph,
    /// mapped to the glyph code so both paths render the same symbol.
    private static let specialCharacterGlyphs: [String: Int] = [
        " ": 0x09, // kMenuSpaceGlyph
        "\r": 0x0B, // kMenuReturnGlyph
        "\u{3}": 0x04, // kMenuEnterGlyph
        "\t": 0x02, // kMenuTabRightGlyph
        "\u{1B}": 0x1B, // kMenuEscapeGlyph
        "\u{7F}": 0x17, // kMenuDeleteLeftGlyph
        "\u{8}": 0x17, // kMenuDeleteLeftGlyph (backspace)
    ]

    /// Uppercases printable characters, but keeps a character whose uppercase
    /// form is longer (e.g. "ß" -> "SS") so a key always renders as one key.
    /// Whitespace, control and private-use characters cannot be shown: nil.
    private static func characterSymbol(_ character: String) -> String? {
        if let glyph = specialCharacterGlyphs[character] {
            return MenuGlyph.symbol(for: glyph)
        }
        guard !character.isEmpty, character.unicodeScalars.allSatisfy(isDisplayable) else {
            return nil
        }
        let uppercased = character.uppercased()
        return uppercased.count == character.count ? uppercased : character
    }

    private static func isDisplayable(_ scalar: Unicode.Scalar) -> Bool {
        let properties = scalar.properties
        return !properties.isWhitespace
            && properties.generalCategory != .control
            && properties.generalCategory != .privateUse
    }
}
