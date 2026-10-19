import ShortcutLensCore
import Testing

struct ShortcutRecordingTests {
    @Test(arguments: [
        ModifierMask(), .shift, .option, [.option, .noCommand], [.control, .noCommand], [.shift, .control],
    ])
    func acceptsACharacterKeyWithCommandOptionOrControl(_ modifiers: ModifierMask) {
        #expect(ShortcutRecording.problem(key: "k", modifiers: modifiers) == nil)
    }

    @Test(arguments: ["1", "ø", ",", "+", "å"])
    func acceptsDigitsLettersAndPunctuation(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: []) == nil)
    }

    @Test(arguments: [ModifierMask.noCommand, [.shift, .noCommand]])
    func needsCommandOptionOrControl(_ modifiers: ModifierMask) {
        #expect(ShortcutRecording.problem(key: "k", modifiers: modifiers) == .needsModifier)
    }

    /// Space, Return, keypad Enter, Tab, Escape, Delete, Forward Delete, Left
    /// Arrow and Page Down, as key events report them.
    @Test(arguments: [" ", "\r", "\u{3}", "\t", "\u{1B}", "\u{7F}", "\u{F728}", "\u{F702}", "\u{F72D}"])
    func acceptsNamedKeysWithAModifier(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: [.control, .noCommand]) == nil)
        #expect(ShortcutRecording.problem(key: key, modifiers: []) == nil)
    }

    @Test(arguments: [" ", "\r", "\u{F702}"])
    func namedKeysOtherThanFunctionKeysNeedAModifier(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: [.shift, .noCommand]) == .needsModifier)
    }

    /// F1, F5 and F19, alone or with Shift, as System Settings allows.
    @Test(arguments: ["\u{F704}", "\u{F708}", "\u{F716}"])
    func acceptsFunctionKeysWithoutAModifier(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: .noCommand) == nil)
        #expect(ShortcutRecording.problem(key: key, modifiers: [.shift, .noCommand]) == nil)
    }

    /// Insert, F20, a private-use character AppKit does not use and a no-break
    /// space: keys without a menu symbol.
    @Test(arguments: ["\u{F727}", "\u{F717}", "\u{E000}", "\u{A0}"])
    func rejectsKeysWithoutASymbol(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: []) == .unsupportedKey)
    }

    /// The store's modifier characters, a lone combining mark, and no or several keys.
    @Test(arguments: ["@", "$", "~", "^", "\u{301}", "", "kk"])
    func rejectsKeysTheStoreCannotHold(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: []) == .unsupportedKey)
    }

    /// The layout gives F1 and F5 both as U+0010, Up as U+001E and Forward
    /// Delete as U+007F (Delete); AppKit's own characters tell them apart.
    @Test(arguments: [
        (122, "\u{10}", "\u{F704}"), (96, "\u{10}", "\u{F708}"), (126, "\u{1E}", "\u{F700}"),
        (117, "\u{7F}", "\u{F728}"), (51, "\u{8}", "\u{7F}"), (36, "\r", "\r"),
    ])
    func namedKeyIsRecordedAsAppKitsCharacter(_ keyCode: Int, _ layoutCharacter: String, _ appKitCharacter: String) {
        let key = ShortcutRecording.key(
            keyCode: keyCode, layoutCharacter: layoutCharacter, appKitCharacter: appKitCharacter
        )

        #expect(key == appKitCharacter)
    }

    /// For character keys the layout's character wins: AppKit's applies Shift.
    @Test func characterKeyIsRecordedAsTheLayoutCharacter() {
        #expect(ShortcutRecording.key(keyCode: 0, layoutCharacter: "a", appKitCharacter: "A") == "a")
        #expect(ShortcutRecording.key(keyCode: 41, layoutCharacter: "æ", appKitCharacter: "Æ") == "æ")
    }

    @Test func everyProblemExplainsItself() {
        let problems: [ShortcutRecording.Problem] = [.needsModifier, .unsupportedKey]

        #expect(problems.allSatisfy { !$0.message.isEmpty })
        #expect(Set(problems.map(\.message)).count == problems.count)
    }
}
