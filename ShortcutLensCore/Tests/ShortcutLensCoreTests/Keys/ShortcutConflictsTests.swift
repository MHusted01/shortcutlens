import Foundation
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

    /// A recorded or stored F1 is a character, the menu reports it as a glyph.
    @Test func aFunctionKeyCharacterAndItsGlyphAreOneCombo() {
        let character = MenuShortcut(title: "Zoom", keyCharacter: "\u{F704}", modifiers: .option)
        let glyph = MenuShortcut(title: "Help", keyCharacter: nil, modifiers: .option, glyph: 0x6F)

        #expect(KeyCombo(character) == KeyCombo(glyph))
    }

    /// A menu reports Up Arrow as a glyph, a recorded shortcut as AppKit's
    /// character and a pack by name; all keep the internal arrow symbol.
    @Test func anArrowFromAMenuARecordingAndAPackIsOneCombo() throws {
        let glyph = MenuShortcut(title: "Enclosing Folder", keyCharacter: nil, modifiers: [], glyph: 0x68)
        let recorded = MenuShortcut(title: "Up", keyCharacter: "\u{F700}", modifiers: [])
        let json = """
        {"schemaVersion": 1, "bundleIdentifier": "a.b", "sections": [{"title": "Go",
         "shortcuts": [{"title": "Up", "key": "Up", "modifiers": ["command"]}]}]}
        """
        let pack = try ShortcutPackParser.parse(Data(json.utf8)).get()
        let packed = try #require(pack.sections.first?.shortcuts.first)

        #expect(KeyCombo(glyph) == KeyCombo(key: "↑", modifiers: []))
        #expect(KeyCombo(recorded) == KeyCombo(glyph))
        #expect(KeyCombo(packed) == KeyCombo(glyph))
    }

    /// Combos keep the English word, whatever language the overlay shows it in.
    @Test func theHelpGlyphAndAPackHelpKeyAreOneCombo() {
        let menu = MenuShortcut(title: "Help", keyCharacter: nil, modifiers: [], glyph: 0x67)

        #expect(KeyCombo(menu) == KeyCombo(key: "Help", modifiers: []))
    }

    @Test func isNilWithoutADisplayableKey() {
        #expect(KeyCombo(MenuShortcut(title: "None", keyCharacter: nil, modifiers: [])) == nil)
    }
}

struct ShortcutConflictsTests {
    private typealias Entry = ShortcutConflicts.Entry
    private typealias Clashes = ShortcutConflicts.Clashes

    private func entry(_ location: String, _ key: String, _ modifiers: ModifierMask = []) -> Entry {
        Entry(combo: KeyCombo(key: key, modifiers: modifiers), location: location)
    }

    /// Clashes that name every location.
    private func all(_ locations: String...) -> Clashes {
        Clashes(shown: locations, total: locations.count)
    }

    @Test func findsDuplicatesWithinAnApp() {
        let clashes = ShortcutConflicts.clashes(among: [
            entry("File > Close", "W"),
            entry("Window > Close Tab", "W"),
            entry("File > Save", "S"),
        ])

        #expect(clashes == [all("Window > Close Tab"), all("File > Close"), .none])
    }

    @Test func differentModifiersDoNotClash() {
        let clashes = ShortcutConflicts.clashes(among: [
            entry("File > Save", "S"),
            entry("File > Save As…", "S", .shift),
            entry("File > Close", "W"),
            entry("File > Close All", "W", .option),
            entry("Edit > Select", "S", .noCommand),
        ])

        #expect(clashes == Array(repeating: .none, count: 5))
    }

    @Test func listsOtherShortcutsInInputOrder() {
        let clashes = ShortcutConflicts.clashes(among: [
            entry("A > One", "K"),
            entry("B > Two", "K"),
            entry("C > Three", "K"),
        ])

        #expect(clashes[1] == all("A > One", "C > Three"))
    }

    /// Past the limit only a count is kept, so many rows on one key
    /// combination never build a long list per row.
    @Test func namesTheFirstClashesAndCountsTheRest() {
        let entries = (0 ..< 2000).map { entry("Pack > Item \($0)", "K") }

        let clashes = ShortcutConflicts.clashes(among: entries)

        #expect(clashes[0] == Clashes(shown: ["Pack > Item 1", "Pack > Item 2", "Pack > Item 3"], total: 1999))
        #expect(clashes[2] == Clashes(shown: ["Pack > Item 0", "Pack > Item 1", "Pack > Item 3"], total: 1999))
        #expect(clashes.allSatisfy { $0.shown.count == ShortcutConflicts.shownLimit })
    }

    /// Two items with the same title are still two items; only an entry
    /// itself is left out.
    @Test func sameTitledItemsClash() {
        let clashes = ShortcutConflicts.clashes(among: [entry("File > Close", "W"), entry("File > Close", "W")])

        #expect(clashes == [all("File > Close"), all("File > Close")])
    }

    @Test func entriesWithoutAComboNeverClash() {
        let clashes = ShortcutConflicts.clashes(among: [
            Entry(combo: nil, location: "A > One"),
            Entry(combo: nil, location: "B > Two"),
        ])

        #expect(clashes == [.none, .none])
    }

    @Test func explainsWhatAShortcutClashesWith() {
        #expect(ShortcutConflicts.explanation(for: .none) == nil)
        #expect(ShortcutConflicts.explanation(for: all("System > Lock Screen")) == "Also used by System > Lock Screen")
        #expect(ShortcutConflicts.explanation(for: all("A > One", "B > Two")) == "Also used by A > One, B > Two")
    }

    @Test func countsTheClashesItDoesNotName() {
        let one = Clashes(shown: ["A", "B", "C"], total: 4)
        let five = Clashes(shown: ["A", "B", "C"], total: 8)

        #expect(ShortcutConflicts.explanation(for: one) == "Also used by A, B, C and 1 more")
        #expect(ShortcutConflicts.explanation(for: five) == "Also used by A, B, C and 5 more")
    }

    @Test func shortensLongTitlesInALocation() {
        let long = String(repeating: "x", count: 500)
        let limit = ShortcutConflicts.titleLimit
        let shortened = String(repeating: "x", count: limit - 1) + "…"

        #expect(ShortcutConflicts.location(section: "File", title: "Close") == "File > Close")
        #expect(ShortcutConflicts.location(section: long, title: "Close") == "\(shortened) > Close")
        #expect(ShortcutConflicts.location(section: "File", title: long) == "File > \(shortened)")
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

    @Test func aLongSectionTitleIsShortenedInTheExplanation() {
        let section = String(repeating: "S", count: 1000)
        let items = [entry("A", key: "k", element: 1), entry("B", key: "k", element: 2)]
        let groups = [MenuGroup(title: section, items: items)]

        let rows = OverlayContent(appName: "App", groups: groups).sections[0].rows
        let explanation = rows[0].conflict ?? ""

        #expect(explanation.count < 100)
        #expect(explanation.hasSuffix("… > B"))
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
