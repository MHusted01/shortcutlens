/// Checks a recorded shortcut before it is written as an App Shortcut.
///
/// Only character keys are supported: function keys, arrows and other named
/// keys are stored as private-use characters that need their own mapping.
public enum ShortcutRecording {
    /// Why a recorded shortcut cannot be saved.
    public enum Problem: Error, Hashable, Sendable {
        /// Neither Command, Option nor Control is held.
        case needsModifier
        /// Space, Return, an arrow, a function key and the like.
        case namedKey
        /// Not exactly one displayable key, or a character the store uses for
        /// modifiers.
        case unsupportedKey

        public var message: String {
            switch self {
            case .needsModifier:
                "Add Command, Option or Control."
            case .namedKey:
                "Function keys, arrows and other named keys are not supported yet."
            case .unsupportedKey:
                "This key cannot be used for an App Shortcut."
            }
        }
    }

    /// Nil when `key` with `modifiers` can be saved. `key` is the character
    /// the key types without modifiers.
    public static func problem(key: String, modifiers: ModifierMask) -> Problem? {
        guard key.count == 1, !reservedCharacters.contains(key) else {
            return .unsupportedKey
        }
        if key.unicodeScalars.contains(where: isNamed) {
            return .namedKey
        }
        guard ShortcutFormatter.keySymbol(for: MenuShortcut(title: "", keyCharacter: key, modifiers: modifiers)) != nil
        else {
            return .unsupportedKey
        }
        let hasModifier = modifiers.includesCommand || !modifiers.isDisjoint(with: [.option, .control])
        return hasModifier ? nil : .needsModifier
    }

    /// The store's modifier characters; see `UserKeyEquivalent`.
    private static let reservedCharacters: Set<String> = ["@", "$", "~", "^"]

    private static func isNamed(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isWhitespace {
            return true
        }
        switch scalar.properties.generalCategory {
        case .control, .format, .privateUse:
            return true
        default:
            return false
        }
    }
}
