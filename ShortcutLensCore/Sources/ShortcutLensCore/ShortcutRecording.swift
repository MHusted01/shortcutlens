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

    /// The store's modifier characters; see `UserKeyEquivalent`.
    private static let reservedCharacters: Set<String> = ["@", "$", "~", "^"]
}
