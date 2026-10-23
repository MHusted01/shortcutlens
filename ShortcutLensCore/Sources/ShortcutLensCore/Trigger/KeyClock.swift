/// One reading of the clock and of the HID key state, taken by the app when
/// it passes an input to `TriggerCoordinator`.
///
/// Both values are seconds on the same monotonic clock (system uptime), so
/// a `MissedKeyDown` can tell whether a key went down after it was armed.
public struct KeyClock: Equatable, Sendable {
    public let now: Double
    /// Seconds since the last hardware key press; may be huge or invalid
    /// when none was seen.
    public let secondsSinceLastKeyDown: Double

    public init(now: Double, secondsSinceLastKeyDown: Double) {
        self.now = now
        self.secondsSinceLastKeyDown = secondsSinceLastKeyDown
    }

    /// Whether a key went down after `watch` was armed.
    public func keyWentDown(since watch: MissedKeyDown) -> Bool {
        watch.keyWentDown(now: now, secondsSinceLastKeyDown: secondsSinceLastKeyDown)
    }
}
