import Foundation

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
        "⌃": String(localized: "Control", bundle: .module),
        "⌥": String(localized: "Option", bundle: .module),
        "⇧": String(localized: "Shift", bundle: .module),
        "⌘": String(localized: "Command", bundle: .module),
    ]

    /// `MenuGlyph` symbols, then punctuation keys.
    private static let keyNames: [String: String] = [
        "⇥": String(localized: "Tab", bundle: .module),
        "⇤": String(localized: "Back Tab", bundle: .module),
        "⌤": String(localized: "Enter", bundle: .module),
        "⌦": String(localized: "Forward Delete", bundle: .module),
        "↩": String(localized: "Return", bundle: .module),
        "⌫": String(localized: "Delete", bundle: .module),
        "⎋": String(localized: "Escape", bundle: .module),
        "⌧": String(localized: "Clear", bundle: .module),
        "⇞": String(localized: "Page Up", bundle: .module),
        "⇟": String(localized: "Page Down", bundle: .module),
        "↖": String(localized: "Home", bundle: .module),
        "↘": String(localized: "End", bundle: .module),
        "←": String(localized: "Left Arrow", bundle: .module),
        "→": String(localized: "Right Arrow", bundle: .module),
        "↑": String(localized: "Up Arrow", bundle: .module),
        "↓": String(localized: "Down Arrow", bundle: .module),
        ",": String(localized: "Comma", bundle: .module),
        ".": String(localized: "Period", bundle: .module),
        "/": String(localized: "Slash", bundle: .module),
        ";": String(localized: "Semicolon", bundle: .module),
        "'": String(localized: "Apostrophe", bundle: .module),
        "[": String(localized: "Left Bracket", bundle: .module),
        "]": String(localized: "Right Bracket", bundle: .module),
        "\\": String(localized: "Backslash", bundle: .module),
        "-": String(localized: "Minus", bundle: .module),
        "=": String(localized: "Equals", bundle: .module),
        "+": String(localized: "Plus", bundle: .module),
        "`": String(localized: "Grave Accent", bundle: .module),
        "?": String(localized: "Question Mark", bundle: .module),
        // MenuGlyph shows these two as words.
        "Space": String(localized: "Space", bundle: .module),
        "Help": String(localized: "Help", bundle: .module),
    ]
}
