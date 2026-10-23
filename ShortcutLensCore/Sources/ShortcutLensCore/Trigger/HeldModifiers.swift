/// The modifier keys currently held, as far as the trigger cares. Left and
/// right keys are not told apart; Caps Lock and fn are not tracked.
public struct HeldModifiers: OptionSet, Hashable, Sendable {
    public static let command = HeldModifiers(rawValue: 1 << 0)
    public static let shift = HeldModifiers(rawValue: 1 << 1)
    public static let option = HeldModifiers(rawValue: 1 << 2)
    public static let control = HeldModifiers(rawValue: 1 << 3)

    public let rawValue: Int

    /// Device-independent flag bits, shared by `NSEvent.ModifierFlags` and
    /// `CGEventFlags`, for each tracked modifier.
    private static let eventFlagBits: [(bit: UInt, modifier: HeldModifiers)] = [
        (1 << 17, .shift), (1 << 18, .control), (1 << 19, .option), (1 << 20, .command),
    ]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The tracked modifiers in an event's modifier flags, such as
    /// `NSEvent.ModifierFlags.rawValue`. Other bits are ignored.
    public init(eventFlags: UInt) {
        let held = Self.eventFlagBits.filter { eventFlags & $0.bit != 0 }.map(\.modifier)
        self = HeldModifiers(held)
    }

    /// Whether Command is held and no other tracked modifier is.
    public var isCommandAlone: Bool {
        self == .command
    }
}
