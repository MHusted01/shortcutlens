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

    /// Tests run with `-testLanguage en`, so the catalog gives the English words.
    @Test func defaultsToTheCatalogWords() {
        #expect(KeyDisplay.text(for: "⌥⌘Space") == "⌥⌘Space")
        #expect(KeyDisplay.text(for: "⌘Help") == "⌘Help")
    }
}
