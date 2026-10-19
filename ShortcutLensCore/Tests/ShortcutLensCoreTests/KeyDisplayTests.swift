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
        #expect(KeyDisplay.text(for: keys, words: danish) == expected)
    }

    @Test(arguments: ["⌘S", "⌃F5", "⇧⌘↑", "⌘Ø", "", "⌘"])
    func keepsOtherKeys(_ keys: String) {
        #expect(KeyDisplay.text(for: keys, words: danish) == keys)
    }

    /// Only the whole key is a word; a key never contains one.
    @Test(arguments: ["⌘Spacebar", "⌘Helper", "Space⌘"])
    func translatesOnlyTheWholeKey(_ keys: String) {
        #expect(KeyDisplay.text(for: keys, words: danish) == keys)
    }

    @Test func englishWordsLeaveKeysUnchanged() {
        let english = KeyDisplay.Words(space: "Space", help: "Help")

        #expect(KeyDisplay.text(for: "⌘Space", words: english) == "⌘Space")
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
}
