import ShortcutLensCore
import Testing

struct UserKeyEquivalentsTests {
    private func entry(_ title: String, _ keys: String) throws -> UserKeyEquivalent {
        try #require(UserKeyEquivalent(title: title, keys: keys))
    }

    private func shortcut(
        _ path: [String], key: String?, modifiers: ModifierMask = [], glyph: Int? = nil
    ) -> MenuShortcut {
        MenuShortcut(title: path.last ?? "", keyCharacter: key, modifiers: modifiers, glyph: glyph, menuPath: path)
    }

    @Test func plainTitleMarksItemsWithThatTitleInAnyMenu() throws {
        let custom = try UserKeyEquivalents(global: [], app: [entry("Export…", "@e")])

        #expect(custom.isCustom(shortcut(["File", "Export…"], key: "E")))
        #expect(custom.isCustom(shortcut(["Edit", "More", "Export…"], key: "e")))
        #expect(!custom.isCustom(shortcut(["File", "Save"], key: "E")))
    }

    @Test func menuPathMarksOnlyTheItemAtThatPath() throws {
        let custom = try UserKeyEquivalents(global: [], app: [entry("\u{1B}File\u{1B}Export…", "@e")])

        #expect(custom.isCustom(shortcut(["File", "Export…"], key: "e")))
        #expect(!custom.isCustom(shortcut(["Edit", "Export…"], key: "e")))
    }

    @Test func itemWhoseKeysDifferFromTheEntryIsNotMarked() throws {
        let custom = try UserKeyEquivalents(global: [], app: [entry("Save", "@$s")])

        #expect(custom.isCustom(shortcut(["File", "Save"], key: "S", modifiers: .shift)))
        #expect(!custom.isCustom(shortcut(["File", "Save"], key: "S")))
        #expect(!custom.isCustom(shortcut(["File", "Save"], key: "D", modifiers: .shift)))
    }

    /// The store holds F1 as a private-use character, the menu reports a glyph.
    @Test func glyphItemIsMatchedByItsKeyAndModifiers() throws {
        let custom = try UserKeyEquivalents(global: [], app: [entry("Zoom", "@~\u{F704}")])

        #expect(custom.isCustom(shortcut(["View", "Zoom"], key: nil, modifiers: .option, glyph: 0x6F)))
        #expect(!custom.isCustom(shortcut(["View", "Zoom"], key: nil, glyph: 0x6F)))
        #expect(!custom.isCustom(shortcut(["View", "Zoom"], key: nil, modifiers: .option, glyph: 0x70)))
    }

    @Test(arguments: [("\u{F700}", 0x68), ("\r", 0x0B), ("\t", 0x02), (" ", 0x09), ("\u{7F}", 0x17), ("\u{1B}", 0x1B)])
    func namedKeyEntryMarksTheItemShowingItsGlyph(_ key: String, _ glyph: Int) throws {
        let custom = try UserKeyEquivalents(global: [], app: [entry("Zoom", "^" + key)])

        #expect(custom.isCustom(shortcut(["View", "Zoom"], key: nil, modifiers: [.control, .noCommand], glyph: glyph)))
    }

    @Test func globalEntriesApplyToEveryApp() throws {
        let custom = try UserKeyEquivalents(global: [entry("Save", "@k")], app: [])

        #expect(custom.isCustom(shortcut(["File", "Save"], key: "K")))
    }

    @Test func appEntryOverridesTheGlobalOneForTheSameItem() throws {
        let custom = try UserKeyEquivalents(global: [entry("Save", "@k")], app: [entry("Save", "@j")])

        #expect(custom.isCustom(shortcut(["File", "Save"], key: "J")))
        #expect(!custom.isCustom(shortcut(["File", "Save"], key: "K")))
    }

    @Test func plainTitleAndMenuPathAreDifferentEntries() throws {
        let custom = try UserKeyEquivalents(
            global: [entry("Save", "@k")], app: [entry("\u{1B}Edit\u{1B}Save", "@j")]
        )

        #expect(custom.isCustom(shortcut(["File", "Save"], key: "K")))
        #expect(custom.isCustom(shortcut(["Edit", "Save"], key: "J")))
    }

    @Test func emptyMarksNothing() {
        #expect(!UserKeyEquivalents.empty.isCustom(shortcut(["File", "Save"], key: "s")))
        #expect(UserKeyEquivalents.empty.isEmpty)
    }
}
