/// One entry of `NSUserKeyEquivalents`, the store behind System Settings >
/// Keyboard > Keyboard Shortcuts > App Shortcuts.
///
/// The entry's dictionary key names the menu item: a plain title matches every
/// item with that title, a title starting with the escape character is a menu
/// path (`"\u{1B}File\u{1B}Export…"`). The value is the shortcut: modifier
/// characters (`@` Command, `~` Option, `$` Shift, `^` Control) followed by
/// exactly one key.
public struct UserKeyEquivalent: Hashable, Sendable {
    /// The separator AppKit uses in menu paths.
    public static let pathSeparator: Character = "\u{1B}"

    /// The menu item's own title, the last path component for a menu path.
    public let title: String
    /// Titles from the top-level menu down to the item; nil for a plain title.
    public let menuPath: [String]?
    /// The key, lowercased. An uppercase letter in the store implies Shift.
    public let key: String
    public let modifiers: ModifierMask

    /// Parses one entry; nil when the title or the keys are malformed.
    public init?(title: String, keys: String) {
        guard let path = Self.path(from: title), let (key, modifiers) = Self.shortcut(from: keys) else {
            return nil
        }
        self.title = path.last ?? title
        menuPath = title.first == Self.pathSeparator ? path : nil
        self.key = key
        self.modifiers = modifiers
    }

    /// Reads an `NSUserKeyEquivalents` dictionary. The input is untrusted:
    /// values that are not strings and malformed entries are skipped.
    public static func parse(_ dictionary: [String: Any]) -> [Self] {
        dictionary.compactMap { title, value in
            (value as? String).flatMap { Self(title: title, keys: $0) }
        }
    }

    /// The path components, `[title]` for a plain title, nil when empty or
    /// when a component is empty.
    private static func path(from title: String) -> [String]? {
        guard title.first == pathSeparator else {
            return title.isEmpty || title.contains(pathSeparator) ? nil : [title]
        }
        let components = title.dropFirst().split(separator: pathSeparator, omittingEmptySubsequences: false)
        guard !components.contains(where: \.isEmpty) else {
            return nil
        }
        return components.map(String.init)
    }

    private static let modifierCharacters: [Character: ModifierMask] = [
        "$": .shift, "~": .option, "^": .control,
    ]

    /// Splits `"@$k"` into the key and its modifiers; nil unless every
    /// character but the last is a modifier and the last one is not.
    private static func shortcut(from keys: String) -> (String, ModifierMask)? {
        guard let last = keys.last, !isModifier(last) else {
            return nil
        }
        let prefix = keys.dropLast()
        guard prefix.allSatisfy(isModifier) else {
            return nil
        }
        let base: ModifierMask = prefix.contains("@") ? [] : .noCommand
        let modifiers = prefix.compactMap { modifierCharacters[$0] }.reduce(base) { $0.union($1) }
        let key = String(last)
        let lowercased = key.lowercased()
        return lowercased == key ? (key, modifiers) : (lowercased, modifiers.union(.shift))
    }

    private static func isModifier(_ character: Character) -> Bool {
        character == "@" || modifierCharacters[character] != nil
    }
}
