import ShortcutLensCore
import Testing

struct OptionAlternatesTests {
    private func entry(
        _ title: String,
        key: String = "Q",
        modifiers: ModifierMask = [],
        glyph: Int? = nil,
        path: [String] = ["File"],
        element: Int = 0
    ) -> MenuEntry<Int> {
        MenuEntry(
            shortcut: MenuShortcut(
                title: title,
                keyCharacter: key,
                modifiers: modifiers,
                glyph: glyph,
                menuPath: path + [title]
            ),
            element: element
        )
    }

    @Test func removesOptionVariantFollowingItsPrimary() {
        let quit = entry("Quit")
        let keep = entry("Quit and Keep Windows", modifiers: .option)

        #expect(OptionAlternates.removed(from: [quit, keep]) == [quit])
    }

    @Test func removesOptionVariantOfShiftedPrimary() {
        let saveAs = entry("Save As", key: "S", modifiers: .shift)
        let saveAll = entry("Save All", key: "S", modifiers: [.shift, .option])

        #expect(OptionAlternates.removed(from: [saveAs, saveAll]) == [saveAs])
    }

    @Test func removesOptionVariantOfShortcutWithoutCommand() {
        let primary = entry("Next", key: "\t", modifiers: .noCommand)
        let alternate = entry("Next Group", key: "\t", modifiers: [.noCommand, .option])

        #expect(OptionAlternates.removed(from: [primary, alternate]) == [primary])
    }

    @Test func keepsOptionShortcutWithDifferentKey() {
        let close = entry("Close", key: "W")
        let other = entry("Minimize All", key: "M", modifiers: .option)

        #expect(OptionAlternates.removed(from: [close, other]) == [close, other])
    }

    @Test func keepsOptionShortcutThatDoesNotFollowItsPrimary() {
        let close = entry("Close", key: "W")
        let middle = entry("Save", key: "S")
        let closeAll = entry("Close All", key: "W", modifiers: .option)

        #expect(OptionAlternates.removed(from: [close, middle, closeAll]) == [close, middle, closeAll])
    }

    @Test func keepsOptionShortcutFromAnotherSubmenu() {
        let primary = entry("Find", key: "F", path: ["Edit"])
        let nested = entry("Find in Project", key: "F", modifiers: .option, path: ["Edit", "Find"])

        #expect(OptionAlternates.removed(from: [primary, nested]) == [primary, nested])
    }

    @Test func keepsVariantThatDiffersByMoreThanOption() {
        let primary = entry("Paste", key: "V")
        let variant = entry("Paste and Match Style", key: "V", modifiers: [.shift, .option])

        #expect(OptionAlternates.removed(from: [primary, variant]) == [primary, variant])
    }

    @Test func keepsPrimaryThatAlreadyHasOption() {
        let primary = entry("Hide Others", key: "H", modifiers: .option)
        let next = entry("Hide Others Too", key: "H", modifiers: .option)

        #expect(OptionAlternates.removed(from: [primary, next]) == [primary, next])
    }

    @Test func comparesGlyphKeys() {
        let primary = entry("Back", key: "", glyph: 0x6C)
        let alternate = entry("Back All", key: "", modifiers: .option, glyph: 0x6C)
        let otherGlyph = entry("Forward All", key: "", modifiers: .option, glyph: 0x6D)

        #expect(OptionAlternates.removed(from: [primary, alternate, otherGlyph]) == [primary, otherGlyph])
    }

    @Test func comparesKeysCaseInsensitively() {
        let primary = entry("Quit", key: "q")
        let alternate = entry("Quit and Keep Windows", key: "Q", modifiers: .option)

        #expect(OptionAlternates.removed(from: [primary, alternate]) == [primary])
    }

    @Test func removesFromEveryGroup() {
        let file = MenuGroup(title: "File", items: [
            entry("Close", key: "W"),
            entry("Close All", key: "W", modifiers: .option),
        ])
        let app = MenuGroup(title: "App", items: [entry("Quit", path: ["App"])])

        let groups = OptionAlternates.removed(from: [file, app])

        #expect(groups.map(\.title) == ["File", "App"])
        #expect(groups.map(\.items.count) == [1, 1])
    }
}
