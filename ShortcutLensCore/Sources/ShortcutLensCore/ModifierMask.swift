/// Modifier keys of a menu shortcut, decoded from `AXMenuItemCmdModifiers`.
///
/// Command is implied unless `noCommand` is set, so an empty mask means
/// Command alone. Only the four defined bits are kept, so every initializer
/// produces the same mask for, say, 24 and 8.
public struct ModifierMask: OptionSet, Hashable, Sendable {
    /// Shift is held (bit value 1).
    public static let shift = ModifierMask(rawValue: 1 << 0)
    /// Option is held (bit value 2).
    public static let option = ModifierMask(rawValue: 1 << 1)
    /// Control is held (bit value 4).
    public static let control = ModifierMask(rawValue: 1 << 2)
    /// Command is not part of the shortcut (bit value 8).
    public static let noCommand = ModifierMask(rawValue: 1 << 3)

    /// The bits `AXMenuItemCmdModifiers` defines; everything above is ignored.
    private static let definedBits = 0b1111

    public let rawValue: Int

    /// Creates a mask from raw bits, dropping any bit above `noCommand`.
    public init(rawValue: Int) {
        self.rawValue = rawValue & Self.definedBits
    }

    /// Decodes a raw accessibility value. Bits above `noCommand` are dropped,
    /// so 24 behaves like 8. Negative values are not valid AX values and are
    /// treated as Command alone.
    public init(axValue: Int) {
        self.init(rawValue: max(axValue, 0))
    }

    /// Whether Command is part of the shortcut.
    public var includesCommand: Bool {
        !contains(.noCommand)
    }
}
