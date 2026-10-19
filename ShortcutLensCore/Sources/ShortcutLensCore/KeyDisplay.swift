import Foundation

/// The keys of a shortcut as the UI shows them. `MenuGlyph` names Space and
/// Help with English words, which stay the internal symbols that `KeyCombo`,
/// packs and recorded shortcuts match on; only the shown text is translated,
/// e.g. `⌘Space` becomes `⌘Mellemrum` in Danish, as macOS menus show it.
public enum KeyDisplay {
    /// The shown words for the keys `MenuGlyph` names with a word.
    public struct Words: Sendable {
        public let space: String
        public let help: String

        public init(space: String, help: String) {
            self.space = space
            self.help = help
        }

        /// The words in the app's language.
        public static var localized: Words {
            Words(
                space: String(localized: "Space", bundle: .module),
                help: String(localized: "Help", bundle: .module)
            )
        }
    }

    /// `keys` with a Space or Help key in the app's language.
    public static func text(for keys: String) -> String {
        text(for: keys, words: .localized)
    }

    /// `keys` with a Space or Help key replaced by `words`. Only a whole key
    /// after the modifier symbols is replaced; anything else is kept.
    public static func text(for keys: String, words: Words) -> String {
        let modifiers = keys.prefix { modifierSymbols.contains($0) }
        let key = keys.dropFirst(modifiers.count)
        switch key {
        case "Space":
            return modifiers + words.space
        case "Help":
            return modifiers + words.help
        default:
            return keys
        }
    }

    private static let modifierSymbols: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]
}
