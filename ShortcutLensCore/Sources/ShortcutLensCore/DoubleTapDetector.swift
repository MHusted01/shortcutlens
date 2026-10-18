/// Detects a double tap of Command: Command pressed alone and released twice
/// in quick succession, with no other key, modifier or click in between.
///
/// Each press may last at most `interval` seconds, and the second press must
/// start at most `interval` seconds after the first release. The double tap
/// is reported on the second release; the detector then starts over, so a
/// triple tap is reported once. A Command left over from a chord (Cmd+Shift,
/// then Shift released) is not a tap: every modifier must be released first.
///
/// Times are seconds on one monotonic clock, such as `NSEvent.timestamp`.
public struct DoubleTapDetector: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case modifiersChanged(HeldModifiers, time: Double)
        /// A key press or click.
        case otherInput
    }

    private enum Phase: Equatable, Sendable {
        case idle
        /// Command is down alone since `time`; `isSecond` when it follows a tap.
        case pressed(time: Double, isSecond: Bool)
        /// A tap ended at `time`.
        case tapped(time: Double)
        /// Other input was seen; waits until every modifier is released.
        case blocked
    }

    /// Seconds allowed for each press and for the gap between the taps.
    public static let interval: Double = 0.35

    public static let initial = Self(phase: .idle)

    private let phase: Phase

    /// The state after `event`, and whether it completed a double tap.
    public func updated(with event: Event) -> (state: Self, detected: Bool) {
        guard case let .modifiersChanged(modifiers, time) = event else {
            return (Self(phase: phase == .idle ? .idle : .blocked), false)
        }
        if modifiers.isEmpty {
            return released(at: time)
        }
        guard modifiers.isCommandAlone else {
            return (Self(phase: .blocked), false)
        }
        return pressed(at: time)
    }

    private func pressed(at time: Double) -> (state: Self, detected: Bool) {
        switch phase {
        case .idle:
            (Self(phase: .pressed(time: time, isSecond: false)), false)
        case let .tapped(tapTime):
            (Self(phase: .pressed(time: time, isSecond: time - tapTime <= Self.interval)), false)
        case .pressed, .blocked:
            (self, false)
        }
    }

    private func released(at time: Double) -> (state: Self, detected: Bool) {
        guard case let .pressed(pressTime, isSecond) = phase, time - pressTime <= Self.interval else {
            return (Self(phase: .idle), false)
        }
        return isSecond ? (Self(phase: .idle), true) : (Self(phase: .tapped(time: time)), false)
    }
}
