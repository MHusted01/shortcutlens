/// Tells whether a key went down after a moment, from a "seconds since the
/// last key press" reading.
///
/// System hotkeys such as Cmd+Space are consumed by macOS before the event
/// monitors see them, so the trigger asks the HID system state instead. All
/// times are seconds on one monotonic clock (for example system uptime).
public struct MissedKeyDown: Equatable, Sendable {
    /// When the countdown started or the overlay appeared.
    public let armedAt: Double

    public init(armedAt: Double) {
        self.armedAt = armedAt
    }

    /// Whether the last key press happened strictly after `armedAt`.
    /// Negative, infinite or NaN readings count as no key press.
    public func keyWentDown(now: Double, secondsSinceLastKeyDown: Double) -> Bool {
        guard secondsSinceLastKeyDown.isFinite, secondsSinceLastKeyDown >= 0 else {
            return false
        }
        return now - secondsSinceLastKeyDown > armedAt
    }
}
