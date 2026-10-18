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
/// The detection reports when the first press started, so the caller can
/// check for key presses its event monitors never saw (system hotkeys).
public struct DoubleTapDetector: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case modifiersChanged(HeldModifiers, time: Double)
        /// A key press or click.
        case otherInput
    }

    private enum Phase: Equatable, Sendable {
        case idle
        /// Command is down alone since `time`. `firstPress` is set when this
        /// press follows a tap, to the time that tap started.
        case pressed(time: Double, firstPress: Double?)
        /// A tap that started at `pressedAt` ended at `time`.
        case tapped(time: Double, pressedAt: Double)
        /// Other input was seen; waits until every modifier is released.
        case blocked
    }

    /// Seconds allowed for each press and for the gap between the taps.
    public static let interval: Double = 0.35

    public static let initial = Self(phase: .idle)

    private let phase: Phase

    /// The state after `event`, and the time the first press started when
    /// `event` completed a double tap.
    public func updated(with event: Event) -> (state: Self, startedAt: Double?) {
        guard case let .modifiersChanged(modifiers, time) = event else {
            return (Self(phase: phase == .idle ? .idle : .blocked), nil)
        }
        if modifiers.isEmpty {
            return released(at: time)
        }
        guard modifiers.isCommandAlone else {
            return (Self(phase: .blocked), nil)
        }
        return (pressed(at: time), nil)
    }

    private func pressed(at time: Double) -> Self {
        switch phase {
        case .idle:
            Self(phase: .pressed(time: time, firstPress: nil))
        case let .tapped(tapTime, pressedAt):
            Self(phase: .pressed(time: time, firstPress: time - tapTime <= Self.interval ? pressedAt : nil))
        case .pressed, .blocked:
            self
        }
    }

    private func released(at time: Double) -> (state: Self, startedAt: Double?) {
        guard case let .pressed(pressTime, firstPress) = phase, time - pressTime <= Self.interval else {
            return (Self(phase: .idle), nil)
        }
        guard let firstPress else {
            return (Self(phase: .tapped(time: time, pressedAt: pressTime)), nil)
        }
        return (Self(phase: .idle), firstPress)
    }
}
