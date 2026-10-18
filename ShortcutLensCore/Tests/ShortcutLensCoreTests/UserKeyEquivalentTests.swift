import ShortcutLensCore
import Testing

struct UserKeyEquivalentTests {
    @Test func parsesEachModifier() {
        #expect(UserKeyEquivalent(title: "A", keys: "@k")?.modifiers == [])
        #expect(UserKeyEquivalent(title: "A", keys: "@$k")?.modifiers == .shift)
        #expect(UserKeyEquivalent(title: "A", keys: "@~k")?.modifiers == .option)
        #expect(UserKeyEquivalent(title: "A", keys: "@^k")?.modifiers == .control)
        #expect(UserKeyEquivalent(title: "A", keys: "^k")?.modifiers == [.control, .noCommand])
    }

    @Test func parsesAllModifiersTogetherInAnyOrder() {
        let shortcut = UserKeyEquivalent(title: "A", keys: "$^~@k")

        #expect(shortcut?.modifiers == [.shift, .option, .control])
        #expect(shortcut?.key == "k")
    }

    @Test func uppercaseLetterImpliesShift() {
        let shortcut = UserKeyEquivalent(title: "A", keys: "@K")

        #expect(shortcut?.key == "k")
        #expect(shortcut?.modifiers == .shift)
    }

    @Test func plainTitleHasNoMenuPath() {
        let shortcut = UserKeyEquivalent(title: "Export…", keys: "@e")

        #expect(shortcut?.title == "Export…")
        #expect(shortcut?.menuPath == nil)
    }

    @Test func escapeSeparatedTitleIsAMenuPath() {
        let shortcut = UserKeyEquivalent(title: "\u{1B}File\u{1B}Export\u{1B}PDF…", keys: "@e")

        #expect(shortcut?.title == "PDF…")
        #expect(shortcut?.menuPath == ["File", "Export", "PDF…"])
    }

    /// Empty, modifiers without a key, more than one key, or a key before a modifier.
    @Test(arguments: ["", "@", "@~$^", "@kk", "@k@", "x@k"])
    func rejectsInvalidKeys(_ keys: String) {
        #expect(UserKeyEquivalent(title: "A", keys: keys) == nil)
    }

    /// Empty, an empty path component, or a separator inside a plain title.
    @Test(arguments: [
        "", "\u{1B}", "\u{1B}File\u{1B}", "\u{1B}File\u{1B}\u{1B}Save", "\u{1B}\u{1B}Save", "File\u{1B}Save",
    ])
    func rejectsInvalidTitles(_ title: String) {
        #expect(UserKeyEquivalent(title: title, keys: "@k") == nil)
    }

    @Test func parsesADictionaryAndSkipsInvalidEntries() {
        let parsed = UserKeyEquivalent.parse([
            "Save": "@s",
            "Broken": "@kk",
            "NotAString": 7,
            "": "@x",
        ])

        #expect(parsed == [UserKeyEquivalent(title: "Save", keys: "@s")])
    }
}
