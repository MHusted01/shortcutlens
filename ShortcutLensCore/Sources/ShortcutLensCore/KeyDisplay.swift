import Foundation

/// The keys of a shortcut as the UI shows them. `MenuGlyph` names Space and
/// Help with English words, which stay the internal symbols that `KeyCombo`,
/// packs and recorded shortcuts match on; only the shown text is translated,
/// e.g. `⌘Space` becomes `⌘Mellemrum` in Danish, as macOS menus show it.
/// Arrow keys are drawn the way the system's menus draw them.
public enum KeyDisplay {
    /// How menus draw the arrow keys `MenuGlyph` names `←→↑↓`.
    public enum ArrowStyle: Equatable, Sendable {
        case arrows
        /// `◀▶▲▼`, as macOS 27 menus draw them.
        case triangles

        /// Triangles from macOS 27; only 27 was checked (#80).
        public init(macOSMajorVersion: Int) {
            self = macOSMajorVersion >= 27 ? .triangles : .arrows
        }

        /// The running system's style.
        public static let current = ArrowStyle(
            macOSMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }

    /// The shown words for the keys `MenuGlyph` names with a word.
    public struct Words: Equatable, Sendable {
        public let space: String
        public let help: String

        public init(space: String, help: String) {
            self.space = space
            self.help = help
        }

        /// The words in the catalog's `language`, e.g. "da"; nil when Core
        /// has no localization for it.
        public init?(language: String) {
            guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
                  let bundle = Bundle(path: path)
            else {
                return nil
            }
            self.init(
                space: bundle.localizedString(forKey: "Space", value: nil, table: nil),
                help: bundle.localizedString(forKey: "Help", value: nil, table: nil)
            )
        }

        /// The words in the app's language, looked up once: the app's
        /// language only changes with a relaunch.
        public static let localized = Words(
            space: String(localized: "Space", bundle: .module),
            help: String(localized: "Help", bundle: .module)
        )
    }

    /// `keys` with a Space or Help key in the app's language and an arrow key
    /// in the system's menu style.
    public static func text(for keys: String) -> String {
        text(for: keys, words: .localized, arrows: .current)
    }

    /// `keys` with a Space or Help key replaced by `words` and an arrow key
    /// drawn in `arrows`. Only a whole key after the modifier symbols is
    /// replaced; anything else is kept.
    public static func text(for keys: String, words: Words, arrows: ArrowStyle) -> String {
        let modifiers = keys.prefix { modifierSymbols.contains($0) }
        let key = keys.dropFirst(modifiers.count)
        switch key {
        case "Space":
            return modifiers + words.space
        case "Help":
            return modifiers + words.help
        default:
            guard arrows == .triangles, let triangle = triangles[String(key)] else {
                return keys
            }
            return modifiers + triangle
        }
    }

    private static let triangles: [String: String] = ["←": "◀", "→": "▶", "↑": "▲", "↓": "▼"]

    private static let modifierSymbols: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]
}
