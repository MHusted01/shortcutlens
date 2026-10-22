/// The modifier keys currently held, as far as the trigger cares. Left and
/// right keys are not told apart; Caps Lock and fn are not tracked.
public struct HeldModifiers: OptionSet, Hashable, Sendable {
    public static let command = HeldModifiers(rawValue: 1 << 0)
    public static let shift = HeldModifiers(rawValue: 1 << 1)
    public static let option = HeldModifiers(rawValue: 1 << 2)
    public static let control = HeldModifiers(rawValue: 1 << 3)

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Whether Command is held and no other tracked modifier is.
    public var isCommandAlone: Bool {
        self == .command
    }
}
