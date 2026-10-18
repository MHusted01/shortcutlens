import ShortcutLensCore
import Testing

struct ShortcutFormatterTests {
    @Test(arguments: [
        (0, "⌘"), (1, "⇧⌘"), (2, "⌥⌘"), (3, "⌥⇧⌘"),
        (4, "⌃⌘"), (5, "⌃⇧⌘"), (6, "⌃⌥⌘"), (7, "⌃⌥⇧⌘"),
        (8, ""), (9, "⇧"), (10, "⌥"), (11, "⌥⇧"),
        (12, "⌃"), (13, "⌃⇧"), (14, "⌃⌥"), (15, "⌃⌥⇧"),
    ])
    func rendersModifiersInHIGOrder(value: Int, expected: String) {
        #expect(ShortcutFormatter.modifierSymbols(for: ModifierMask(axValue: value)) == expected)
    }

    @Test(arguments: [(24, ""), (19, "⌥⇧⌘")])
    func rendersOutOfRangeValueLikeItsLowBits(value: Int, expected: String) {
        #expect(ShortcutFormatter.modifierSymbols(for: ModifierMask(axValue: value)) == expected)
    }

    @Test(arguments: [
        (" ", "Space"), ("\r", "↩"), ("\n", "↩"), ("\u{3}", "⌤"), ("\t", "⇥"),
        ("\u{1B}", "⎋"), ("\u{7F}", "⌫"), ("\u{8}", "⌫"),
    ])
    func rendersSpecialCharactersAsKeySymbols(keyCharacter: String, expected: String) {
        let shortcut = makeShortcut(keyCharacter: keyCharacter, modifiers: 8)

        #expect(ShortcutFormatter.keySymbol(for: shortcut) == expected)
    }

    @Test func treatsCombiningSequenceAsOneKey() {
        let shortcut = makeShortcut(keyCharacter: "e\u{301}", modifiers: 0)

        #expect(ShortcutFormatter.string(for: shortcut) == "⌘E\u{301}")
    }

    @Test func keepsCharacterWhoseUppercaseIsLonger() {
        let shortcut = makeShortcut(keyCharacter: "ß", modifiers: 0)

        #expect(ShortcutFormatter.string(for: shortcut) == "⌘ß")
    }

    @Test func rendersCharacterShortcut() {
        let shortcut = makeShortcut(keyCharacter: "s", modifiers: 1)

        #expect(ShortcutFormatter.string(for: shortcut) == "⇧⌘S")
    }

    @Test func prefersKnownGlyphOverCharacter() {
        let shortcut = makeShortcut(keyCharacter: "\u{F704}", glyph: 0x6F, modifiers: 8)

        #expect(ShortcutFormatter.string(for: shortcut) == "F1")
    }

    @Test func fallsBackToCharacterWhenGlyphIsUnknown() {
        let shortcut = makeShortcut(keyCharacter: "q", glyph: 0x7B, modifiers: 0)

        #expect(ShortcutFormatter.string(for: shortcut) == "⌘Q")
    }

    @Test func rendersGlyphOnlyShortcut() {
        let shortcut = makeShortcut(keyCharacter: nil, glyph: 0x17, modifiers: 2)

        #expect(ShortcutFormatter.string(for: shortcut) == "⌥⌘⌫")
    }

    @Test(arguments: [
        (String?.none, Int?.none),
        (String?.some(""), Int?.none),
        (String?.none, Int?.some(0x7B)),
        (String?.some("\u{F704}"), Int?.some(0x7B)),
        (String?.some("\u{F704}"), Int?.none),
        (String?.some("\u{0}"), Int?.none),
        (String?.some("  "), Int?.none),
        (String?.some("ab"), Int?.none),
        (String?.some("\u{200B}"), Int?.none),
        (String?.some("\u{FEFF}"), Int?.none),
        (String?.some("\u{301}"), Int?.none),
    ])
    func returnsNilWithoutUsableKey(keyCharacter: String?, glyph: Int?) {
        let shortcut = makeShortcut(keyCharacter: keyCharacter, glyph: glyph, modifiers: 0)

        #expect(ShortcutFormatter.keySymbol(for: shortcut) == nil)
        #expect(ShortcutFormatter.string(for: shortcut) == nil)
    }

    private func makeShortcut(keyCharacter: String?, glyph: Int? = nil, modifiers: Int) -> MenuShortcut {
        MenuShortcut(
            title: "Item",
            keyCharacter: keyCharacter,
            modifiers: ModifierMask(axValue: modifiers),
            glyph: glyph
        )
    }
}
