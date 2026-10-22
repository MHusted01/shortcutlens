/// The keys pressed to answer a practice question, as read from a key event.
///
/// A key with a glyph (arrows, F-keys, Space, ...) is named by its key code,
/// because it types a private-use or invisible character. Other keys are
/// named by the character they type without modifiers.
public struct PracticePress: Equatable, Sendable {
    /// The virtual key code (`kVK_*`).
    public let keyCode: Int
    /// What the key types without modifiers, in the current layout.
    public let character: String?
    /// What the key types with Shift, e.g. `?` for `/` on a US layout.
    public let shiftedCharacter: String?
    public let modifiers: ModifierMask

    public init(keyCode: Int, character: String?, shiftedCharacter: String?, modifiers: ModifierMask) {
        self.keyCode = keyCode
        self.character = character
        self.shiftedCharacter = shiftedCharacter
        self.modifiers = modifiers
    }

    /// The keys as menus show them, e.g. `⌥⌘S`; nil when the key has no symbol.
    public var label: String? {
        combo(for: character).map { ShortcutFormatter.modifierSymbols(for: $0.modifiers) + $0.key }
    }

    /// Whether these keys run a shortcut with `expected`. With Shift held,
    /// the shifted character also counts, whether the menu lists Shift or
    /// not: apps report Help as ⇧⌘? or as ⌘?, both pressed as ⇧⌘/.
    public func matches(_ expected: KeyCombo) -> Bool {
        if combo(for: character) == expected {
            return true
        }
        guard modifiers.contains(.shift), let shifted = combo(for: shiftedCharacter) else {
            return false
        }
        return shifted.key == expected.key
            && shifted.modifiers.subtracting(.shift) == expected.modifiers.subtracting(.shift)
    }

    private func combo(for character: String?) -> KeyCombo? {
        KeyCombo(MenuShortcut(
            title: "", keyCharacter: character, modifiers: modifiers, glyph: KeyCodes.glyph(for: keyCode)
        ))
    }
}
