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

    /// Space, Return, Tab, Escape, Delete, F1 and Left Arrow.
    @Test(arguments: [" ", "\r", "\t", "\u{1B}", "\u{7F}", "\u{F704}", "\u{F702}"])
    func rejectsNamedKeys(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: []) == .namedKey)
    }

    /// The store's modifier characters, a lone combining mark, and no or several keys.
    @Test(arguments: ["@", "$", "~", "^", "\u{301}", "", "kk"])
    func rejectsKeysTheStoreCannotHold(_ key: String) {
        #expect(ShortcutRecording.problem(key: key, modifiers: []) == .unsupportedKey)
    }

    @Test func everyProblemExplainsItself() {
        let problems: [ShortcutRecording.Problem] = [.needsModifier, .namedKey, .unsupportedKey]

        #expect(problems.allSatisfy { !$0.message.isEmpty })
        #expect(Set(problems.map(\.message)).count == problems.count)
    }
}
