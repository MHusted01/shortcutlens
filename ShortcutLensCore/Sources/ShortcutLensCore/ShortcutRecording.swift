/// Checks a recorded shortcut before it is written as an App Shortcut.
///
/// Named keys (F1, arrows, Return, ...) are recorded as the characters AppKit
/// reports for them, which is also how the store holds them; see `NamedKeys`.
public enum ShortcutRecording {
    /// Why a recorded shortcut cannot be saved.
    public enum Problem: Error, Hashable, Sendable {
        /// Neither Command, Option nor Control is held, and the key is not a
        /// function key.
        case needsModifier
        /// Not exactly one key with a menu symbol, or a character the store
        /// uses for modifiers.
        case unsupportedKey

        public var message: String {
            switch self {
            case .needsModifier:
                "Add Command, Option or Control."
            case .unsupportedKey:
                "This key cannot be used for an App Shortcut."
            }
        }
    }

    /// Nil when `key` with `modifiers` can be saved. `key` is the character
    /// the key types without modifiers. F1...F19 need no modifier, as in
    /// System Settings.
    public static func problem(key: String, modifiers: ModifierMask) -> Problem? {
        guard key.count == 1, !reservedCharacters.contains(key),
              ShortcutFormatter.keySymbol(for: MenuShortcut(title: "", keyCharacter: key, modifiers: modifiers)) != nil
        else {
            return .unsupportedKey
        }
        if NamedKeys.isFunctionKey(key) {
            return nil
        }
        let hasModifier = modifiers.includesCommand || !modifiers.isDisjoint(with: [.option, .control])
        return hasModifier ? nil : .needsModifier
    }

    /// The key to record for a key event with `keyCode`. A key with a menu
    /// glyph takes AppKit's character (`charactersIgnoringModifiers`, F1 is
    /// U+F704), because the layout gives legacy codes that cannot tell F1 from
    /// F5 or Forward Delete from Delete. AppKit's character applies Shift
    /// (Shift-Tab is back-tab), so it is used only when it shows the pressed
    /// key. Otherwise the layout's character without modifiers wins
    /// (`characters(byApplyingModifiers: [])`).
    public static func key(keyCode: Int, layoutCharacter: String, appKitCharacter: String) -> String {
        guard let glyph = KeyCodes.glyph(for: keyCode), NamedKeys.glyph(for: appKitCharacter) == glyph else {
            return layoutCharacter
        }
        return appKitCharacter
    }

    /// The store's modifier characters; see `UserKeyEquivalent`.
    private static let reservedCharacters: Set<String> = ["@", "$", "~", "^"]
}
