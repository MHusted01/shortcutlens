import ShortcutLensCore
import Testing

struct KeyLabelsTests {
    /// Danish layout: the key next to Z types "<", the ISO section key "§".
    private let danish = KeyLabels(keyCodes: [0, 10, 41, 50]) { keyCode in
        [0: "a", 10: "§", 41: "æ", 50: "<"][keyCode]
    }

    private func label(
        _ character: Character?, _ keyCode: Int?, _ modifiers: ModifierMask = [], layout: KeyLabels
    ) -> String? {
        let binding = SymbolicHotKeyBinding(character: character, keyCode: keyCode, modifiers: modifiers)
        return ShortcutFormatter.string(for: binding.shortcut(title: "Test", layout: layout))
    }

    @Test func translatedKeysAreKept() {
        #expect(danish.label(for: 50) == "<")
        #expect(danish.label(for: 41) == "æ")
        #expect(danish.label(for: 1) == nil)
    }

    /// No result, empty, several characters, whitespace, control, private
    /// use (AppKit's F1), format (left-to-right mark) and unassigned.
    @Test(arguments: [nil, "", "ab", " ", "\r", "\u{10}", "\u{F704}", "\u{200E}", "\u{378}"])
    func dropsResultsThatAreNotAKeyLabel(_ result: String?) {
        let labels = KeyLabels(keyCodes: [0]) { _ in result }

        #expect(labels.label(for: 0) == nil)
    }

    @Test func layoutWinsOverTheStoredCharacter() {
        // The built-in defaults store US characters; the system matches the key code.
        #expect(label("`", 50, layout: danish) == "⌘<")
        #expect(label(nil, 41, layout: danish) == "⌘Æ")
    }

    @Test func layoutLabelsKeysTheUSTableLacks() {
        #expect(label(nil, 10, layout: danish) == "⌘§")
        #expect(label(nil, 10, layout: .none) == nil)
    }

    @Test func missingTranslationFallsBackToTheStoredCharacter() {
        #expect(label("3", 20, [.shift], layout: danish) == "⇧⌘3")
    }

    @Test func missingTranslationFallsBackToTheUSLayout() {
        #expect(label(nil, 18, layout: danish) == "⌘1")
    }

    @Test func glyphKeysIgnoreTheLayout() {
        let labels = KeyLabels(keyCodes: [49, 123]) { _ in "x" }

        #expect(label(nil, 49, layout: labels) == "⌘Space")
        #expect(label(nil, 123, layout: labels) == "⌘←")
    }

    @Test func catalogUsesTheLayout() {
        let labels = KeyLabels(keyCodes: [20]) { _ in "\"" }
        let shortcuts = SystemHotKeyCatalog.shortcuts(from: [:], layout: labels)
        let screenshot = shortcuts.first { $0.title == "Save picture of screen as a file" }

        #expect(screenshot.flatMap(ShortcutFormatter.string) == "⇧⌘\"")
    }
}
