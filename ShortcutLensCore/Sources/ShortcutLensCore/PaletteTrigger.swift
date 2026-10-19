/// How the command palette opens: a double tap of one modifier, or not at
/// all. A choice besides Command avoids Dictation's "Press Command Key Twice".
/// Shift is not offered, since it is tapped often while typing.
public enum PaletteTrigger: String, CaseIterable, Sendable {
    case command
    case option
    case control
    case off

    /// The modifier to double-tap; nil when the palette has no trigger.
    public var modifier: HeldModifiers? {
        switch self {
        case .command: .command
        case .option: .option
        case .control: .control
        case .off: nil
        }
    }
}
