import ShortcutLensCore
import Testing

struct HeldModifiersTests {
    private static let shift: UInt = 1 << 17
    private static let control: UInt = 1 << 18
    private static let option: UInt = 1 << 19
    private static let command: UInt = 1 << 20

    @Test func commandAloneIsOnlyCommand() {
        #expect(HeldModifiers.command.isCommandAlone)
        #expect(!HeldModifiers([.command, .shift]).isCommandAlone)
        #expect(!HeldModifiers.shift.isCommandAlone)
        #expect(!HeldModifiers().isCommandAlone)
    }

    // MARK: - Event flags

    /// The device-independent bits `NSEvent.ModifierFlags` and `CGEventFlags` share.
    @Test func noFlagsIsEmpty() {
        #expect(HeldModifiers(eventFlags: 0).isEmpty)
    }

    @Test(arguments: [
        (command, HeldModifiers.command),
        (shift, HeldModifiers.shift),
        (option, HeldModifiers.option),
        (control, HeldModifiers.control),
    ])
    func singleFlagMapsToItsModifier(flags: UInt, expected: HeldModifiers) {
        #expect(HeldModifiers(eventFlags: flags) == expected)
    }

    @Test func combinedFlagsMapToAllModifiers() {
        let flags = Self.command | Self.shift | Self.option | Self.control

        #expect(HeldModifiers(eventFlags: flags) == [.command, .shift, .option, .control])
    }

    /// Caps Lock (bit 16), fn (bit 23) and the device-dependent left/right
    /// bits are not tracked.
    @Test func untrackedFlagsAreIgnored() {
        let flags = Self.command | 1 << 16 | 1 << 23 | 0x08

        #expect(HeldModifiers(eventFlags: flags).isCommandAlone)
    }
}
