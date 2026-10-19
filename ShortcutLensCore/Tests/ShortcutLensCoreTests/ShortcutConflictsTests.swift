import ShortcutLensCore
import Testing

struct KeyComboTests {
    @Test func ignoresTheCaseOfTheKey() {
        let lower = MenuShortcut(title: "Save", keyCharacter: "s", modifiers: [])
        let upper = MenuShortcut(title: "Save", keyCharacter: "S", modifiers: [])

        #expect(KeyCombo(lower) == KeyCombo(upper))
        #expect(KeyCombo(lower) == KeyCombo(key: "S", modifiers: []))
    }

    @Test func differentModifiersAreDifferentCombos() {
        let save = MenuShortcut(title: "Save", keyCharacter: "s", modifiers: [])
        let saveAs = MenuShortcut(title: "Save As…", keyCharacter: "s", modifiers: .shift)

        #expect(KeyCombo(save) != KeyCombo(saveAs))
    }

    /// Some apps report Space as a character, the system as a glyph.
    @Test func aGlyphAndACharacterForTheSameKeyAreOneCombo() {
        let character = MenuShortcut(title: "Play", keyCharacter: " ", modifiers: [])
        let glyph = MenuShortcut(title: "Spotlight", keyCharacter: nil, modifiers: [], glyph: 0x09)

        #expect(KeyCombo(character) == KeyCombo(glyph))
    }

    @Test func isNilWithoutADisplayableKey() {
        #expect(KeyCombo(MenuShortcut(title: "None", keyCharacter: nil, modifiers: [])) == nil)
    }
}

struct ShortcutConflictsTests {
    private typealias Entry = ShortcutConflicts.Entry

    private func entry(_ location: String, _ key: String, _ modifiers: ModifierMask = []) -> Entry {
        Entry(combo: KeyCombo(key: key, modifiers: modifiers), location: location)
    }

    @Test func findsDuplicatesWithinAnApp() {
        let clashes = ShortcutConflicts.clashes(among: [
            entry("File > Close", "W"),
            entry("Window > Close Tab", "W"),
            entry("File > Save", "S"),
        ])

        #expect(clashes == [["Window > Close Tab"], ["File > Close"], []])
    }

    @Test func findsAnAppShortcutThatClashesWithASystemShortcut() {
        let clashes = ShortcutConflicts.clashes(among: [
            entry("Edit > Emoji", "Space"),
            entry("System > Show Spotlight search", "Space"),
        ])

        #expect(clashes == [["System > Show Spotlight search"], ["Edit > Emoji"]])
    }

    @Test func differentModifiersDoNotClash() {
        let clashes = ShortcutConflicts.clashes(among: [
            entry("File > Save", "S"),
            entry("File > Save As…", "S", .shift),
            entry("File > Close", "W"),
            entry("File > Close All", "W", .option),
            entry("Edit > Select", "S", .noCommand),
        ])

        #expect(clashes == Array(repeating: [], count: 5))
    }

    @Test func listsEveryOtherShortcutInInputOrder() {
        let clashes = ShortcutConflicts.clashes(among: [
            entry("A > One", "K"),
            entry("B > Two", "K"),
            entry("C > Three", "K"),
        ])

        #expect(clashes[1] == ["A > One", "C > Three"])
    }

    /// Two items with the same title are still two items; only an entry
    /// itself is left out.
    @Test func sameTitledItemsClash() {
        let clashes = ShortcutConflicts.clashes(among: [entry("File > Close", "W"), entry("File > Close", "W")])

        #expect(clashes == [["File > Close"], ["File > Close"]])
    }

    @Test func entriesWithoutAComboNeverClash() {
        let clashes = ShortcutConflicts.clashes(among: [
            Entry(combo: nil, location: "A > One"),
            Entry(combo: nil, location: "B > Two"),
        ])

        #expect(clashes == [[], []])
    }

    @Test func explainsWhatAShortcutClashesWith() {
        #expect(ShortcutConflicts.explanation(for: []) == nil)
        #expect(ShortcutConflicts.explanation(for: ["System > Lock Screen"]) == "Also used by System > Lock Screen")
        #expect(ShortcutConflicts.explanation(for: ["A > One", "B > Two"]) == "Also used by A > One, B > Two")
    }
}

struct OverlayContentConflictTests {
    private func entry(_ title: String, key: String, modifiers: ModifierMask = [], element: Int) -> MenuEntry<Int> {
        MenuEntry(shortcut: MenuShortcut(title: title, keyCharacter: key, modifiers: modifiers), element: element)
    }

    @Test func marksRowsThatClashWithinTheApp() {
        let groups = [
            MenuGroup(
                title: "File",
                items: [entry("Close", key: "w", element: 1), entry("Save", key: "s", element: 2)]
            ),
            MenuGroup(title: "Window", items: [entry("Close Tab", key: "W", element: 3)]),
        ]

        let content = OverlayContent(appName: "App", groups: groups)

        #expect(content.sections[0].rows.map(\.conflict) == ["Also used by Window > Close Tab", nil])
        #expect(content.sections[1].rows.map(\.conflict) == ["Also used by File > Close"])
    }

    @Test func marksAppAndSystemRowsThatClash() {
        let groups = [MenuGroup(title: "Edit", items: [entry("Lock", key: "q", modifiers: .control, element: 1)])]
        let system = MenuShortcut(title: "Lock Screen", keyCharacter: "q", modifiers: .control)

        let content = OverlayContent(appName: "App", groups: groups)
            .appending(sectionTitle: "System", shortcuts: [system])

        #expect(content.sections[0].rows[0].conflict == "Also used by System > Lock Screen")
        #expect(content.sections[1].rows[0].conflict == "Also used by Edit > Lock")
    }

    /// Disabled items still own their keys, so they count.
    @Test func disabledRowsCount() {
        let disabled = MenuEntry(
            shortcut: MenuShortcut(title: "Revert", keyCharacter: "r", modifiers: [], isEnabled: false),
            element: 1
        )
        let groups = [MenuGroup(title: "File", items: [disabled, entry("Reload", key: "r", element: 2)])]

        let rows = OverlayContent(appName: "App", groups: groups).sections[0].rows

        #expect(rows.map(\.conflict) == ["Also used by File > Reload", "Also used by File > Revert"])
    }

    @Test func aRowWithAConflictTakesTwoLines() {
        let items = [
            entry("Close", key: "w", element: 1),
            entry("Close Tab", key: "w", element: 2),
            entry("Save", key: "s", element: 3),
        ]
        let groups = [MenuGroup(title: "File", items: items)]

        let section = OverlayContent(appName: "App", groups: groups).sections[0]

        #expect(section.rows.map(\.lineCount) == [2, 2, 1])
        #expect(section.lineCount == 5)
    }
}
