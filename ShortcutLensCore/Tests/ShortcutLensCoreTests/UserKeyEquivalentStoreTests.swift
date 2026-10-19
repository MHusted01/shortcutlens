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

    @Test func writtenEntryIsReadBackByParse() throws {
        let entry = try #require(UserKeyEquivalent(menuPath: ["File", "Save"], key: "s", modifiers: .control))

        let parsed = UserKeyEquivalent.parse(UserKeyEquivalent.setting(entry, in: [:]))

        #expect(parsed == [entry])
    }
}
