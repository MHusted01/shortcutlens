/// Decides when the overlay shows: Command held alone for `delay` seconds.
///
/// Any other modifier, key press, click or interruption during the countdown cancels it, so
/// normal shortcuts such as Cmd+C never show the overlay. After a cancel the
/// trigger stays suppressed until every modifier is released; going from
/// Cmd+Shift back to Cmd does not start a new countdown.
///
/// Each countdown gets a token; a timer that fires with an older token is
/// ignored, so a late timer from a cancelled countdown cannot show the overlay.
///
/// A double tap of Command (see `DoubleTapDetector`) opens palette mode: the
/// overlay stays open without Command held and takes typed keys. Only an
/// explicit close, a click outside the panel, an interruption or a reset
/// closes it.
public struct TriggerStateMachine: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case countingDown(token: Int)
        case shown
        /// A chord or other input was seen; waits for all modifiers to be released.
        case suppressed
        /// The overlay is open as a command palette and takes typed keys.
        case palette
    }

    public enum Event: Equatable, Sendable {
        case modifiersChanged(HeldModifiers)
        case keyDown
        case mouseDown
        /// A click outside the panel. Like `mouseDown`, but closes the palette.
        case mouseDownOutside
        case timerFired(token: Int)
        /// Focus moved without a key event the monitors saw, such as another
        /// app activating or a Space change. Treated like a key press.
        case interrupted
        /// Monitoring stopped (for example the permission was revoked).
        case reset
        /// Command was double-tapped.
        case doubleTap
        /// The palette asked to close: Escape on an empty query, an item was
        /// run, or the panel lost key status.
        case close
    }

    /// What the app should do after an event.
    public enum Action: Equatable, Sendable {
        case none
        /// Start a one-shot timer that reports `timerFired(token:)` after `delay` seconds.
        case startTimer(token: Int, delay: Double)
        case cancelTimer
        case show
        /// Show the overlay as a palette that takes keyboard focus.
        case showPalette
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
        case .palette:
            fromPalette(event)
        }
    }

    /// A copy with another delay. A countdown already running keeps its
    /// timer; the new delay applies from the next countdown.
    public func with(delay: Double) -> Self {
        Self(phase: phase, delay: delay, nextToken: nextToken)
    }

    private func with(_ phase: Phase) -> Self {
        Self(phase: phase, delay: delay, nextToken: nextToken)
    }

    private func fromIdle(_ event: Event) -> (state: Self, action: Action) {
        if event == .doubleTap {
            return (with(.palette), .showPalette)
        }
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
        case .keyDown, .mouseDown, .mouseDownOutside, .interrupted:
            return (with(.suppressed), .cancelTimer)
        case let .timerFired(firedToken):
            return firedToken == token ? (with(.shown), .show) : (self, .none)
        case .reset:
            return (with(.idle), .cancelTimer)
        case .doubleTap, .close:
            return (self, .none)
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
        case .mouseDown, .mouseDownOutside, .timerFired, .doubleTap, .close:
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

    private func fromPalette(_ event: Event) -> (state: Self, action: Action) {
        switch event {
        case .mouseDownOutside, .interrupted, .close, .reset:
            (with(.idle), .hide)
        case .modifiersChanged, .keyDown, .mouseDown, .timerFired, .doubleTap:
            // Keys and clicks on the panel belong to the palette.
            (self, .none)
        }
    }
}
