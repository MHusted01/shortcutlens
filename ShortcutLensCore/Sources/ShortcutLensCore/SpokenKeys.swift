/// Spells out a shortcut as `ShortcutFormatter` displays it, e.g. `⌃⇧⌘S` as
/// "Control Shift Command S", for VoiceOver. Screen readers read key glyphs
/// inconsistently and skip lone punctuation, so `⌘,` would be just "Command".
public enum SpokenKeys {
    /// The words for `keys`: its leading modifier glyphs, then the key.
    /// Characters without a name, such as letters or `F5`, are kept as they are.
    public static func label(for keys: String) -> String {
        let modifiers = keys.prefix { modifierNames[$0] != nil }
        let key = String(keys.dropFirst(modifiers.count))
        let words = modifiers.compactMap { modifierNames[$0] } + (key.isEmpty ? [] : [keyNames[key] ?? key])
        return words.joined(separator: " ")
    }

    private static let modifierNames: [Character: String] = [
        "⌃": "Control",
        "⌥": "Option",
        "⇧": "Shift",
        "⌘": "Command",
    ]

    /// `MenuGlyph` symbols, then punctuation keys.
    private static let keyNames: [String: String] = [
        "⇥": "Tab",
        "⇤": "Back Tab",
        "⌤": "Enter",
        "⌦": "Forward Delete",
        "↩": "Return",
        "⌫": "Delete",
        "⎋": "Escape",
        "⌧": "Clear",
        "⇞": "Page Up",
        "⇟": "Page Down",
        "↖": "Home",
        "↘": "End",
        "←": "Left Arrow",
        "→": "Right Arrow",
        "↑": "Up Arrow",
        "↓": "Down Arrow",
        ",": "Comma",
        ".": "Period",
        "/": "Slash",
        ";": "Semicolon",
        "'": "Apostrophe",
        "[": "Left Bracket",
        "]": "Right Bracket",
        "\\": "Backslash",
        "-": "Minus",
        "=": "Equals",
        "+": "Plus",
        "`": "Grave Accent",
        "?": "Question Mark",
    ]
}
