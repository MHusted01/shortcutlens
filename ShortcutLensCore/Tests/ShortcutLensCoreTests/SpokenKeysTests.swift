import ShortcutLensCore
import Testing

struct SpokenKeysTests {
    @Test(arguments: [
        ("⌘S", "Command S"),
        ("⇧⌘S", "Shift Command S"),
        ("⌃⌥⇧⌘S", "Control Option Shift Command S"),
        ("⌥A", "Option A"),
        ("A", "A"),
    ])
    func spellsOutModifiers(keys: String, expected: String) {
        #expect(SpokenKeys.label(for: keys) == expected)
    }

    @Test(arguments: [
        ("⇥", "Tab"), ("⇤", "Back Tab"), ("⌤", "Enter"), ("⌦", "Forward Delete"), ("↩", "Return"),
        ("⌫", "Delete"), ("⎋", "Escape"), ("⌧", "Clear"), ("⇞", "Page Up"), ("⇟", "Page Down"),
        ("↖", "Home"), ("↘", "End"), ("←", "Left Arrow"), ("→", "Right Arrow"), ("↑", "Up Arrow"),
        ("↓", "Down Arrow"),
    ])
    func namesKeyGlyphs(keys: String, expected: String) {
        #expect(SpokenKeys.label(for: keys) == expected)
    }

    @Test(arguments: [
        ("⌘,", "Command Comma"), ("⌘.", "Command Period"), ("⌘/", "Command Slash"),
        ("⌘;", "Command Semicolon"), ("⌘'", "Command Apostrophe"), ("⌘[", "Command Left Bracket"),
        ("⌘]", "Command Right Bracket"), ("⌘\\", "Command Backslash"), ("⌘-", "Command Minus"),
        ("⌘=", "Command Equals"), ("⌘+", "Command Plus"), ("⌘`", "Command Grave Accent"),
        ("⇧⌘?", "Shift Command Question Mark"),
    ])
    func namesPunctuationKeys(keys: String, expected: String) {
        #expect(SpokenKeys.label(for: keys) == expected)
    }

    @Test(arguments: [("⌘Space", "Command Space"), ("Help", "Help"), ("⌃F5", "Control F5"), ("⌘Ø", "Command Ø")])
    func keepsWordsAndOtherCharacters(keys: String, expected: String) {
        #expect(SpokenKeys.label(for: keys) == expected)
    }

    @Test
    func readsModifiersOnlyAtTheStart() {
        #expect(SpokenKeys.label(for: "⌘⌫") == "Command Delete")
    }

    @Test
    func emptyKeysGiveAnEmptyLabel() {
        #expect(SpokenKeys.label(for: "").isEmpty)
    }
}
