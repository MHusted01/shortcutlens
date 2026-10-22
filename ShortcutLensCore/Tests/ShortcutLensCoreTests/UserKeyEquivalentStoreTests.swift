import ShortcutLensCore
import Testing

struct UserKeyEquivalentStoreTests {
    private static let allModifierMasks = (0 ... 15).map(ModifierMask.init(rawValue:))

    @Test func storeKeyIsTheEscapeSeparatedMenuPath() {
        #expect(UserKeyEquivalent.storeKey(for: ["File", "Export", "PDF…"]) == "\u{1B}File\u{1B}Export\u{1B}PDF…")
    }

    @Test func storeValueListsModifiersInHIGOrderBeforeTheKey() {
        let entry = UserKeyEquivalent(menuPath: ["File", "Save"], key: "s", modifiers: [.shift, .option, .control])

        #expect(entry?.storeValue == "^~$@s")
    }

    @Test func storeValueLeavesOutCommandWhenItIsNotPartOfTheShortcut() {
        let entry = UserKeyEquivalent(menuPath: ["File", "Save"], key: "s", modifiers: [.control, .noCommand])

        #expect(entry?.storeValue == "^s")
    }

    @Test(arguments: allModifierMasks)
    func roundTripsEveryModifierCombination(_ modifiers: ModifierMask) throws {
        let entry = try #require(UserKeyEquivalent(menuPath: ["Edit", "Find"], key: "f", modifiers: modifiers))

        #expect(entry.modifiers == modifiers)
        #expect(UserKeyEquivalent(title: entry.storeKey, keys: entry.storeValue) == entry)
    }

    @Test(arguments: [["Format", "Font", "Vis skrifter"], ["Ærø", "Søg…"], ["View", "Zoom: 100 %"]])
    func roundTripsMenuPaths(_ menuPath: [String]) throws {
        let entry = try #require(UserKeyEquivalent(menuPath: menuPath, key: "d", modifiers: .option))

        let parsed = UserKeyEquivalent(title: entry.storeKey, keys: entry.storeValue)
        #expect(parsed == entry)
        #expect(parsed?.menuPath == menuPath)
        #expect(parsed?.title == menuPath.last)
    }

    /// F1, F19, the arrows, Forward Delete, Home, End, Page Up and Down, Help,
    /// Return, keypad Enter, Tab, Space, Delete and Escape.
    @Test(arguments: [
        ("\u{F704}", "F1"), ("\u{F716}", "F19"), ("\u{F700}", "↑"), ("\u{F701}", "↓"), ("\u{F702}", "←"),
        ("\u{F703}", "→"), ("\u{F728}", "⌦"), ("\u{F729}", "↖"), ("\u{F72B}", "↘"), ("\u{F72C}", "⇞"),
        ("\u{F72D}", "⇟"), ("\u{F746}", "Help"), ("\r", "↩"), ("\u{3}", "⌤"), ("\t", "⇥"), (" ", "Space"),
        ("\u{7F}", "⌫"), ("\u{1B}", "⎋"),
    ])
    func roundTripsNamedKeysAndShowsTheirSymbol(_ key: String, _ symbol: String) throws {
        let entry = try #require(UserKeyEquivalent(menuPath: ["View", "Zoom"], key: key, modifiers: .option))

        let parsed = try #require(UserKeyEquivalent.parse(UserKeyEquivalent.setting(entry, in: [:])).first)
        let shown = MenuShortcut(title: "Zoom", keyCharacter: parsed.key, modifiers: parsed.modifiers)
        #expect(parsed == entry)
        #expect(ShortcutFormatter.string(for: shown) == "⌥⌘" + symbol)
    }

    @Test func uppercaseKeyIsStoredLowercaseWithShift() {
        let entry = UserKeyEquivalent(menuPath: ["File", "Save"], key: "S", modifiers: [])

        #expect(entry?.key == "s")
        #expect(entry?.modifiers == .shift)
    }

    /// An empty path, an empty component, a separator in a component, or a key
    /// that is empty, longer than one character or a modifier character.
    @Test(arguments: [
        ([String](), "k"), ([""], "k"), (["File", ""], "k"), (["Fi\u{1B}le", "Save"], "k"),
        (["File", "Save"], ""), (["File", "Save"], "kk"), (["File", "Save"], "@"), (["File", "Save"], "$"),
    ])
    func rejectsWhatCannotBeStored(_ menuPath: [String], _ key: String) {
        #expect(UserKeyEquivalent(menuPath: menuPath, key: key, modifiers: []) == nil)
    }

    @Test func settingAddsTheEntryAndKeepsTheOthers() throws {
        let entry = try #require(UserKeyEquivalent(menuPath: ["File", "Save"], key: "s", modifiers: .option))
        let existing: [String: Any] = ["Close": "@w", "\u{1B}Edit\u{1B}Find": "@f"]

        let updated = UserKeyEquivalent.setting(entry, in: existing)

        #expect(updated.count == 3)
        #expect(updated["\u{1B}File\u{1B}Save"] as? String == "~@s")
        #expect(updated["Close"] as? String == "@w")
        #expect(updated["\u{1B}Edit\u{1B}Find"] as? String == "@f")
        #expect(existing.count == 2)
    }

    @Test func settingReplacesTheItemsPreviousEntry() throws {
        let entry = try #require(UserKeyEquivalent(menuPath: ["File", "Save"], key: "s", modifiers: .option))

        let updated = UserKeyEquivalent.setting(entry, in: ["\u{1B}File\u{1B}Save": "@k"])

        #expect(updated.count == 1)
        #expect(updated["\u{1B}File\u{1B}Save"] as? String == "~@s")
    }

    @Test func removingDeletesOnlyTheMenuPathEntry() {
        let existing: [String: Any] = ["Save": "@k", "\u{1B}File\u{1B}Save": "@j", "Close": "@w"]

        let updated = UserKeyEquivalent.removing(menuPath: ["File", "Save"], from: existing)

        #expect(updated.count == 2)
        #expect(updated["\u{1B}File\u{1B}Save"] == nil)
        #expect(updated["Save"] as? String == "@k")
        #expect(existing.count == 3)
    }

    @Test func removingAMissingEntryChangesNothing() {
        let updated = UserKeyEquivalent.removing(menuPath: ["File", "Save"], from: ["Close": "@w"])

        #expect(updated.count == 1)
    }

    @Test func plainTitleEntryIsSetUnderItsTitle() throws {
        let entry = try #require(UserKeyEquivalent(title: "Save", keys: "@k"))

        let updated = UserKeyEquivalent.setting(entry, in: ["Save": "@s"])

        #expect(updated.count == 1)
        #expect(updated["Save"] as? String == "@k")
    }
}
