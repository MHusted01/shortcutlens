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

    /// Tests run with `-testLanguage en`, so the app's language is English.
    @Test func defaultsToTheAppLanguage() {
        #expect(KeyDisplay.Words.localized == KeyDisplay.Words(language: "en"))
        #expect(KeyDisplay.text(for: "⌥⌘Space") == "⌥⌘Space")
    }
}
