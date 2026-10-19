/// Detects a double tap of the `PaletteTrigger` modifier (Command by
/// default): that modifier pressed alone and released twice in quick
/// succession, with no other key, modifier or click in between. With
/// `PaletteTrigger.off` nothing is detected.
///
/// Each press may last at most `interval` seconds, and the second press must
/// start at most `interval` seconds after the first release. The double tap
/// is reported on the second release; the detector then starts over, so a
/// triple tap is reported once. A modifier left over from a chord (Cmd+Shift,
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
        /// The modifier is down alone since `time`. `firstPress` is set when this
        /// press follows a tap, to the time that tap started.
        case pressed(time: Double, firstPress: Double?)
        /// A tap that started at `pressedAt` ended at `time`.
        case tapped(time: Double, pressedAt: Double)
        /// Other input was seen; waits until every modifier is released.
        case blocked
    }

    /// Seconds allowed for each press and for the gap between the taps.
    public static let interval: Double = 0.35

    /// A detector for double-tapping Command.
    public static let initial = Self(trigger: .command)

    private let modifier: HeldModifiers?
    private let phase: Phase

    public init(trigger: PaletteTrigger) {
        self.init(modifier: trigger.modifier, phase: .idle)
    }

    private init(modifier: HeldModifiers?, phase: Phase) {
        self.modifier = modifier
        self.phase = phase
    }

    /// The state after `event`, and the time the first press started when
    /// `event` completed a double tap.
    public func updated(with event: Event) -> (state: Self, startedAt: Double?) {
        guard modifier != nil else {
            return (self, nil)
        }
        guard case let .modifiersChanged(modifiers, time) = event else {
            return (with(phase == .idle ? .idle : .blocked), nil)
        }
        if modifiers.isEmpty {
            return released(at: time)
        }
        guard modifiers == modifier else {
            return (with(.blocked), nil)
        }
        return (pressed(at: time), nil)
    }

    private func pressed(at time: Double) -> Self {
        switch phase {
        case .idle:
            with(.pressed(time: time, firstPress: nil))
        case let .tapped(tapTime, pressedAt):
            with(.pressed(time: time, firstPress: time - tapTime <= Self.interval ? pressedAt : nil))
        case .pressed, .blocked:
            self
        }
    }

    private func released(at time: Double) -> (state: Self, startedAt: Double?) {
        guard case let .pressed(pressTime, firstPress) = phase, time - pressTime <= Self.interval else {
            return (with(.idle), nil)
        }
        guard let firstPress else {
            return (with(.tapped(time: time, pressedAt: pressTime)), nil)
        }
        return (with(.idle), firstPress)
    }

    private func with(_ phase: Phase) -> Self {
        Self(modifier: modifier, phase: phase)
    }
}
