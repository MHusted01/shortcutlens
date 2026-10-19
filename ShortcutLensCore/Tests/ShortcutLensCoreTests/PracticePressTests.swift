import ShortcutLensCore
import Testing

struct PracticePressTests {
    /// kVK_ANSI_S, kVK_ANSI_Slash, kVK_ANSI_Equal, kVK_LeftArrow, kVK_F5, kVK_Space.
    private let sKey = 1
    private let slashKey = 44
    private let equalKey = 24
    private let leftArrowKey = 123
    private let f5Key = 96
    private let spaceKey = 49

    private func combo(_ key: String, _ modifiers: ModifierMask = []) -> KeyCombo {
        KeyCombo(key: key, modifiers: modifiers)
    }

    @Test func matchesACharacterKeyIgnoringCase() {
        let press = PracticePress(keyCode: sKey, character: "s", shiftedCharacter: "S", modifiers: [])

        #expect(press.matches(combo("S")))
        #expect(!press.matches(combo("S", .shift)))
        #expect(!press.matches(combo("D")))
    }

    @Test func modifiersMustMatch() {
        let press = PracticePress(keyCode: sKey, character: "s", shiftedCharacter: "S", modifiers: [.option])

        #expect(press.matches(combo("S", .option)))
        #expect(!press.matches(combo("S")))
        #expect(!press.matches(combo("S", [.option, .shift])))
    }

    @Test func shiftMatchesTheUnshiftedKeyWithShift() {
        let press = PracticePress(keyCode: sKey, character: "s", shiftedCharacter: "S", modifiers: [.shift])

        #expect(press.matches(combo("S", .shift)))
    }

    @Test func shiftMatchesTheShiftedCharacter() {
        let press = PracticePress(keyCode: slashKey, character: "/", shiftedCharacter: "?", modifiers: [.shift])

        // Help: some apps report ⇧⌘?, others ⌘? for the same keys.
        #expect(press.matches(combo("?", .shift)))
        #expect(press.matches(combo("?")))
        #expect(press.matches(combo("/", .shift)))
        #expect(!press.matches(combo("/")))
    }

    @Test func theShiftedCharacterNeedsShift() {
        let press = PracticePress(keyCode: equalKey, character: "=", shiftedCharacter: "+", modifiers: [])

        #expect(press.matches(combo("=")))
        #expect(!press.matches(combo("+")))
    }

    @Test func namedKeysMatchByTheirGlyph() {
        let arrow = PracticePress(
            keyCode: leftArrowKey, character: "\u{F702}", shiftedCharacter: "\u{F702}", modifiers: [.option]
        )
        let function = PracticePress(keyCode: f5Key, character: "\u{F708}", shiftedCharacter: nil, modifiers: [])

        #expect(arrow.matches(combo("←", .option)))
        #expect(function.matches(combo("F5")))
    }

    @Test func spaceMatchesWhetherReportedAsCharacterOrGlyph() {
        let press = PracticePress(keyCode: spaceKey, character: " ", shiftedCharacter: " ", modifiers: [.control])
        let reported = KeyCombo(MenuShortcut(title: "", keyCharacter: " ", modifiers: .control))

        #expect(reported.map(press.matches) == true)
    }

    @Test func labelsWhatWasPressed() {
        let press = PracticePress(keyCode: sKey, character: "s", shiftedCharacter: "S", modifiers: [.option, .shift])
        let arrow = PracticePress(
            keyCode: leftArrowKey, character: "\u{F702}", shiftedCharacter: nil, modifiers: .noCommand
        )

        #expect(press.label == "⌥⇧⌘S")
        #expect(arrow.label == "←")
    }

    @Test func anUndisplayableKeyHasNoLabelAndMatchesNothing() {
        let press = PracticePress(keyCode: 200, character: "\u{F750}", shiftedCharacter: nil, modifiers: [])

        #expect(press.label == nil)
        #expect(!press.matches(combo("S")))
    }
}
