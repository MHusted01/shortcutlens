import ShortcutLensCore
import Testing

struct PaletteTriggerTests {
    @Test func eachDoubleTapTriggerNamesItsModifier() {
        #expect(PaletteTrigger.command.modifier == .command)
        #expect(PaletteTrigger.option.modifier == .option)
        #expect(PaletteTrigger.control.modifier == .control)
        #expect(PaletteTrigger.off.modifier == nil)
    }

    /// The raw values are stored in the settings; renaming one loses the choice.
    @Test func rawValuesAreStable() {
        #expect(PaletteTrigger.allCases.map(\.rawValue) == ["command", "option", "control", "off"])
    }
}
