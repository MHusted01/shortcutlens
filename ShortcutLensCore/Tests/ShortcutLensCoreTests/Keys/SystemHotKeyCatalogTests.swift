import ShortcutLensCore
import Testing

struct SystemHotKeyCatalogTests {
    private func keys(_ hotKeys: [Int: SymbolicHotKey]) -> [String: String] {
        let shortcuts = SystemHotKeyCatalog.shortcuts(from: hotKeys)
        let pairs = shortcuts.map { ($0.title, ShortcutFormatter.string(for: $0) ?? "?") }
        return Dictionary(pairs) { first, _ in first }
    }

    private func binding(_ character: Character?, _ keyCode: Int?, _ modifiers: ModifierMask) -> SymbolicHotKeyBinding {
        SymbolicHotKeyBinding(character: character, keyCode: keyCode, modifiers: modifiers)
    }

    @Test func missingIDsUseTheirDefaults() {
        let keys = keys([:])

        #expect(keys["Show Spotlight search"] == "⌘Space")
        #expect(keys["Mission Control"] == "⌃↑")
        #expect(keys["Show Desktop"] == "F11")
        #expect(keys["Screenshot and recording options"] == "⇧⌘5")
    }

    @Test func shortcutsDisabledByDefaultAreHiddenWithoutAnEntry() {
        #expect(keys([:])["Switch to Desktop 1"] == nil)
    }

    @Test func disabledEntryHidesADefaultOnShortcut() {
        let keys = keys([64: SymbolicHotKey(isEnabled: false, binding: nil)])

        #expect(keys["Show Spotlight search"] == nil)
        #expect(keys["Show Finder search window"] == "⌥⌘Space")
    }

    @Test func enabledEntryShowsADefaultOffShortcut() {
        let hotKeys = [118: SymbolicHotKey(isEnabled: true, binding: binding(nil, 18, [.control, .noCommand]))]

        #expect(keys(hotKeys)["Switch to Desktop 1"] == "⌃1")
    }

    @Test func entryBindingWinsOverTheDefault() {
        let hotKeys = [64: SymbolicHotKey(isEnabled: true, binding: binding(" ", 49, [.option, .noCommand]))]

        #expect(keys(hotKeys)["Show Spotlight search"] == "⌥Space")
    }

    @Test func entryWithoutEnabledFlagUsesTheDefaultFlag() {
        let hotKeys = [118: SymbolicHotKey(isEnabled: nil, binding: binding(nil, 18, [.control, .noCommand]))]

        #expect(keys(hotKeys)["Switch to Desktop 1"] == nil)
    }

    @Test func entryWithoutBindingUsesTheDefaultKeys() {
        let hotKeys = [32: SymbolicHotKey(isEnabled: true, binding: nil)]

        #expect(keys(hotKeys)["Mission Control"] == "⌃↑")
    }

    @Test func shortcutsWithoutAKeyAreHidden() {
        let hotKeys = [
            175: SymbolicHotKey(isEnabled: true, binding: nil),
            160: SymbolicHotKey(isEnabled: true, binding: binding(nil, nil, .noCommand)),
        ]

        let keys = keys(hotKeys)

        #expect(keys["Turn Do Not Disturb on or off"] == nil)
        #expect(keys["Show Launchpad"] == nil)
    }

    @Test func unknownIDsAreDropped() {
        let hotKeys = [99999: SymbolicHotKey(isEnabled: true, binding: binding("a", 0, []))]

        #expect(SystemHotKeyCatalog.shortcuts(from: hotKeys) == SystemHotKeyCatalog.shortcuts(from: [:]))
    }

    @Test func keepsCatalogOrderAndSystemMenuPath() throws {
        let shortcuts = SystemHotKeyCatalog.shortcuts(from: [:])
        let first = try #require(shortcuts.first)

        #expect(first.title == "Show Spotlight search")
        #expect(first.menuPath == ["System", "Show Spotlight search"])
        // Outside `#expect`: the macro cannot take a key path as the predicate.
        let allEnabled = shortcuts.allSatisfy(\.isEnabled)
        #expect(allEnabled)
    }

    @Test func catalogIDsAreUnique() {
        let ids = SystemHotKeyCatalog.definitions.map(\.id)

        #expect(Set(ids).count == ids.count)
    }
}

struct SymbolicHotKeyBindingLabelTests {
    private func label(_ character: Character?, _ keyCode: Int?, _ modifiers: ModifierMask = .noCommand) -> String? {
        let binding = SymbolicHotKeyBinding(character: character, keyCode: keyCode, modifiers: modifiers)
        return ShortcutFormatter.string(for: binding.shortcut(title: "Test"))
    }

    @Test func specialKeysUseTheirSymbol() {
        #expect(label(nil, 123) == "←")
        #expect(label(nil, 126) == "↑")
        #expect(label(nil, 49) == "Space")
        #expect(label(nil, 36) == "↩")
        #expect(label(nil, 53) == "⎋")
    }

    @Test func functionKeysUseTheirName() {
        #expect(label(nil, 122) == "F1")
        #expect(label(nil, 103) == "F11")
        #expect(label(nil, 111) == "F12")
        #expect(label(nil, 80) == "F19")
    }

    @Test func characterParameterWinsOverTheUSLayout() {
        // Danish layout: the key next to Z types "<".
        #expect(label("<", 50, []) == "⌘<")
    }

    @Test func missingCharacterFallsBackToTheUSLayout() {
        #expect(label(nil, 18, [.control, .noCommand]) == "⌃1")
        #expect(label(nil, 0) == "A")
        #expect(label(nil, 44) == "/")
    }

    @Test func storedControlCharacterFallsBackToTheUSLayout() {
        #expect(label("\r", 0) == "A")
        #expect(label("\u{3}", 18) == "1")
    }

    @Test func noKeyGivesNoLabel() {
        #expect(label(nil, nil) == nil)
        #expect(label(nil, 9999) == nil)
    }
}
