import ShortcutLensCore
import Testing

struct MenuShortcutTests {
    @Test func storesAllFields() {
        let shortcut = MenuShortcut(
            title: "Save As…",
            keyCharacter: "S",
            modifiers: [.shift],
            glyph: nil,
            isEnabled: false,
            menuPath: ["File", "Save As…"]
        )

        #expect(shortcut.title == "Save As…")
        #expect(shortcut.keyCharacter == "S")
        #expect(shortcut.modifiers == .shift)
        #expect(shortcut.glyph == nil)
        #expect(!shortcut.isEnabled)
        #expect(shortcut.menuPath == ["File", "Save As…"])
    }

    @Test func defaultsToEnabledWithoutGlyphOrPath() {
        let shortcut = MenuShortcut(title: "Copy", keyCharacter: "C", modifiers: [])

        #expect(shortcut.glyph == nil)
        #expect(shortcut.isEnabled)
        #expect(shortcut.menuPath.isEmpty)
    }
}
