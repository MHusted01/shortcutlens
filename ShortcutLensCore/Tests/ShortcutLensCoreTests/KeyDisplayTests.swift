import ShortcutLensCore
import Testing

struct KeyDisplayTests {
    private let danish = KeyDisplay.Words(space: "Mellemrum", help: "Hjælp")

    @Test(arguments: [
        ("⌘Space", "⌘Mellemrum"),
        ("⌃⌥⇧⌘Space", "⌃⌥⇧⌘Mellemrum"),
        ("Space", "Mellemrum"),
        ("⇧Help", "⇧Hjælp"),
        ("Help", "Hjælp"),
    ])
    func translatesSpaceAndHelp(keys: String, expected: String) {
        #expect(KeyDisplay.text(for: keys, words: danish, arrows: .arrows) == expected)
    }

    @Test(arguments: ["⌘S", "⌃F5", "⇧⌘↑", "⌘Ø", "", "⌘"])
    func keepsOtherKeys(_ keys: String) {
        #expect(KeyDisplay.text(for: keys, words: danish, arrows: .arrows) == keys)
    }

    /// Only the whole key is a word; a key never contains one.
    @Test(arguments: ["⌘Spacebar", "⌘Helper", "Space⌘"])
    func translatesOnlyTheWholeKey(_ keys: String) {
        #expect(KeyDisplay.text(for: keys, words: danish, arrows: .arrows) == keys)
    }

    @Test(arguments: [
        ("←", "◀"), ("→", "▶"), ("↑", "▲"), ("↓", "▼"), ("⌘↑", "⌘▲"), ("⌃⌘→", "⌃⌘▶"), ("⌃⌥⇧⌘↓", "⌃⌥⇧⌘▼"),
    ])
    func drawsArrowsAsTriangles(keys: String, expected: String) {
        #expect(KeyDisplay.text(for: keys, words: danish, arrows: .triangles) == expected)
    }

    @Test(arguments: ["←", "⌘→", "⌃⌘↑", "⇧↓"])
    func keepsArrowsInTheArrowStyle(_ keys: String) {
        #expect(KeyDisplay.text(for: keys, words: danish, arrows: .arrows) == keys)
    }

    /// Only the whole key is an arrow; Space and Help still translate.
    @Test(arguments: [("↑↓", "↑↓"), ("↑⌘", "↑⌘"), ("⌘S", "⌘S"), ("⌘Space", "⌘Mellemrum")])
    func trianglesReplaceOnlyAWholeArrowKey(keys: String, expected: String) {
        #expect(KeyDisplay.text(for: keys, words: danish, arrows: .triangles) == expected)
    }

    /// macOS 27 menus draw filled triangles (checked on 27.0.1, #80).
    @Test(arguments: [
        (14, KeyDisplay.ArrowStyle.arrows), (15, .arrows), (26, .arrows), (27, .triangles), (28, .triangles),
    ])
    func arrowStyleFollowsTheMacOSVersion(majorVersion: Int, expected: KeyDisplay.ArrowStyle) {
        #expect(KeyDisplay.ArrowStyle(macOSMajorVersion: majorVersion) == expected)
    }

    @Test func englishWordsLeaveKeysUnchanged() {
        let english = KeyDisplay.Words(space: "Space", help: "Help")

        #expect(KeyDisplay.text(for: "⌘Space", words: english, arrows: .arrows) == "⌘Space")
    }

    /// The catalog's Danish entries, read from the built Core bundle.
    @Test func catalogHasTheDanishWords() {
        #expect(KeyDisplay.Words(language: "da") == danish)
    }

    @Test func catalogHasTheEnglishWords() {
        #expect(KeyDisplay.Words(language: "en") == KeyDisplay.Words(space: "Space", help: "Help"))
    }

    @Test func unknownLanguageHasNoWords() {
        #expect(KeyDisplay.Words(language: "xx") == nil)
    }

    /// Holds in any run language: the app's words are one of the catalog's.
    @Test func defaultsToTheAppLanguage() {
        let catalog = ["en", "da"].map { KeyDisplay.Words(language: $0) }

        #expect(catalog.contains(KeyDisplay.Words.localized))
        #expect(KeyDisplay.text(for: "⌥⌘Space") == "⌥⌘" + KeyDisplay.Words.localized.space)
    }

    /// Holds on any macOS: the running system picks one of the two styles.
    @Test func defaultsToTheRunningSystemsArrowStyle() {
        let expected = KeyDisplay.ArrowStyle.current == .triangles ? "⌘▲" : "⌘↑"

        #expect(KeyDisplay.text(for: "⌘↑") == expected)
    }
}
