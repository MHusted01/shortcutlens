/// Modifier keys of a menu shortcut, decoded from `AXMenuItemCmdModifiers`.
///
/// Command is implied unless `noCommand` is set, so an empty mask means
/// Command alone.
public struct ModifierMask: OptionSet, Hashable, Sendable {
    public static let shift = ModifierMask(rawValue: 1 << 0)
    public static let option = ModifierMask(rawValue: 1 << 1)
    public static let control = ModifierMask(rawValue: 1 << 2)
    public static let noCommand = ModifierMask(rawValue: 1 << 3)

    /// The bits `AXMenuItemCmdModifiers` defines; everything above is ignored.
    public static let definedBits = 0b1111

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Decodes a raw accessibility value. Bits above `noCommand` are dropped,
    /// so 24 behaves like 8. Negative values are not valid AX values and are
    /// treated as Command alone.
    public init(axValue: Int) {
        self.init(rawValue: axValue < 0 ? 0 : axValue & Self.definedBits)
    }

    public var includesCommand: Bool {
        !contains(.noCommand)
    }
}
