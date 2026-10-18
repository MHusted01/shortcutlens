import ShortcutLensCore
import Testing

struct ModifierMaskTests {
    @Test func readsIndividualBits() {
        #expect(ModifierMask(axValue: 1) == .shift)
        #expect(ModifierMask(axValue: 2) == .option)
        #expect(ModifierMask(axValue: 4) == .control)
        #expect(ModifierMask(axValue: 8) == .noCommand)
    }

    @Test func zeroMeansCommandOnly() {
        let mask = ModifierMask(axValue: 0)

        #expect(mask.isEmpty)
        #expect(mask.includesCommand)
    }

    @Test(arguments: [8, 9, 10, 11, 12, 13, 14, 15])
    func noCommandBitExcludesCommand(value: Int) {
        #expect(!ModifierMask(axValue: value).includesCommand)
    }

    @Test(arguments: [(16, 0), (17, 1), (24, 8), (31, 15), (255, 15), (Int.max, 15)])
    func ignoresBitsAboveNoCommand(value: Int, expected: Int) {
        #expect(ModifierMask(axValue: value) == ModifierMask(axValue: expected))
        #expect(ModifierMask(rawValue: value) == ModifierMask(rawValue: expected))
        #expect(ModifierMask(rawValue: value).rawValue == expected)
    }

    @Test(arguments: [-1, -8, Int.min])
    func negativeValuesMeanCommandOnly(value: Int) {
        #expect(ModifierMask(axValue: value) == [])
    }
}
