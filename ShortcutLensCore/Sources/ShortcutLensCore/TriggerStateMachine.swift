/// Decides when the overlay shows: Command held alone for `delay` seconds.
///
/// Any other modifier, key press, click or interruption during the countdown cancels it, so
/// normal shortcuts such as Cmd+C never show the overlay. After a cancel the
/// trigger stays suppressed until every modifier is released; going from
/// Cmd+Shift back to Cmd does not start a new countdown.
///
/// Each countdown gets a token; a timer that fires with an older token is
/// ignored, so a late timer from a cancelled countdown cannot show the overlay.
public struct TriggerStateMachine: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case countingDown(token: Int)
        case shown
        /// A chord or other input was seen; waits for all modifiers to be released.
        case suppressed
    }

    public enum Event: Equatable, Sendable {
        case modifiersChanged(HeldModifiers)
        case keyDown
        case mouseDown
        case timerFired(token: Int)
        /// Something the monitors cannot see took over, such as the app
        /// switcher (Cmd+Tab) or a Space change. Treated like a key press.
        case interrupted
        /// Monitoring stopped (for example the permission was revoked).
        case reset
    }

    /// What the app should do after an event.
    public enum Action: Equatable, Sendable {
        case none
        /// Start a one-shot timer that reports `timerFired(token:)` after `delay` seconds.
        case startTimer(token: Int, delay: Double)
        case cancelTimer
        case show
        case hide
    }

    /// Seconds Command must be held before the overlay shows.
    public static let defaultDelay: Double = 1.0

    public static let initial = Self(delay: defaultDelay)

    public let phase: Phase
    /// Seconds Command must be held before the overlay shows.
    public let delay: Double
    private let nextToken: Int

    public init(delay: Double) {
        self.init(phase: .idle, delay: delay, nextToken: 0)
    }

    private init(phase: Phase, delay: Double, nextToken: Int) {
        self.phase = phase
        self.delay = delay
        self.nextToken = nextToken
    }

    /// The state after `event`, and the action it calls for.
    public func updated(with event: Event) -> (state: Self, action: Action) {
        switch phase {
        case .idle:
            fromIdle(event)
        case let .countingDown(token):
            fromCountingDown(token: token, event)
        case .shown:
            fromShown(event)
        case .suppressed:
            fromSuppressed(event)
        }
    }

    private func with(_ phase: Phase) -> Self {
        Self(phase: phase, delay: delay, nextToken: nextToken)
    }

    private func fromIdle(_ event: Event) -> (state: Self, action: Action) {
        guard case let .modifiersChanged(modifiers) = event, !modifiers.isEmpty else {
            return (self, .none)
        }
        guard modifiers.isCommandAlone else {
            return (with(.suppressed), .none)
        }
        let token = nextToken
        let state = Self(phase: .countingDown(token: token), delay: delay, nextToken: token &+ 1)
        return (state, .startTimer(token: token, delay: delay))
    }

    private func fromCountingDown(token: Int, _ event: Event) -> (state: Self, action: Action) {
        switch event {
        case let .modifiersChanged(modifiers):
            if modifiers.isCommandAlone {
                return (self, .none)
            }
            return (with(modifiers.isEmpty ? .idle : .suppressed), .cancelTimer)
        case .keyDown, .mouseDown, .interrupted:
            return (with(.suppressed), .cancelTimer)
        case let .timerFired(firedToken):
            return firedToken == token ? (with(.shown), .show) : (self, .none)
        case .reset:
            return (with(.idle), .cancelTimer)
        }
    }

    private func fromShown(_ event: Event) -> (state: Self, action: Action) {
        switch event {
        case let .modifiersChanged(modifiers):
            if modifiers.contains(.command) {
                return (self, .none)
            }
            return (with(modifiers.isEmpty ? .idle : .suppressed), .hide)
        case .keyDown, .interrupted:
            return (with(.suppressed), .hide)
        case .mouseDown, .timerFired:
            // Clicks belong to the overlay (pressing an entry).
            return (self, .none)
        case .reset:
            return (with(.idle), .hide)
        }
    }

    private func fromSuppressed(_ event: Event) -> (state: Self, action: Action) {
        switch event {
        case .reset, .modifiersChanged([]):
            (with(.idle), .none)
        default:
            (self, .none)
        }
    }
}
