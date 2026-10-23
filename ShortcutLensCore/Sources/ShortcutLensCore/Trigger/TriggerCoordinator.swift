/// Every trigger decision behind one input stream: the overlay countdown
/// (`TriggerStateMachine`), the palette double tap (`DoubleTapDetector`) and
/// key presses the event monitors never saw (`MissedKeyDown`).
///
/// The app passes each monitored event, timer tick and interruption in as an
/// `Input`, with a `KeyClock` reading, and carries out the returned effects
/// in order. Each event goes to the state machine first and to the double-tap
/// detector second, so the second release has already ended the countdown
/// when the double tap arrives.
///
/// System hotkeys (Cmd+Space, screenshots) never reach the monitors. The key
/// clock reveals them when the countdown ends, on every shown-overlay poll
/// tick and when a double tap completes; the palette takes typed keys itself.
public struct TriggerCoordinator: Equatable, Sendable {
    public enum Input: Equatable, Sendable {
        /// The held modifiers changed; `time` is the event's timestamp on
        /// the `KeyClock` clock.
        case modifiersChanged(HeldModifiers, time: Double)
        case keyDown
        /// A click; `outside` when it went to another app, not the panel.
        case mouseDown(outside: Bool)
        /// Focus moved without a key event: another app activated or the Space changed.
        case interrupted
        /// The countdown timer for `token` fired. `held` is a fresh reading
        /// of the modifiers, in case a release was missed.
        case countdownEnded(token: Int, held: HeldModifiers)
        /// The shown-overlay poll ticked.
        case shownPollTick
        /// The palette asked to close: Escape, an item was run, or it lost focus.
        case closePalette
        /// Monitoring stopped.
        case reset
    }

    public enum Effect: Equatable, Sendable {
        /// Start a one-shot timer that reports `countdownEnded` after `delay`
        /// seconds, and let the overlay read the menus early.
        case startCountdown(token: Int, delay: Double)
        case cancelCountdown
        /// Start a repeating timer that reports `shownPollTick`.
        case startShownPoll
        case stopShownPoll
        case show
        case showPalette
        /// Hide the overlay; `event` caused it (an event kind, never a key character).
        case hide(after: TriggerStateMachine.Event)
        /// A key press the monitors missed was found. For the log only.
        case missedKeyPress(MissedKeyMoment)
    }

    /// When a missed key press was found.
    public enum MissedKeyMoment: String, Sendable {
        case countdown
        case shownOverlay = "shown overlay"
        case doubleTap = "double tap"
    }

    public static let initial = Self(
        machine: .initial, paletteTrigger: .command, doubleTap: .initial, watch: nil
    )

    public let paletteTrigger: PaletteTrigger
    private let machine: TriggerStateMachine
    private let doubleTap: DoubleTapDetector
    /// Armed when a countdown starts and again when the overlay shows.
    private let watch: MissedKeyDown?

    private init(
        machine: TriggerStateMachine,
        paletteTrigger: PaletteTrigger,
        doubleTap: DoubleTapDetector,
        watch: MissedKeyDown?
    ) {
        self.machine = machine
        self.paletteTrigger = paletteTrigger
        self.doubleTap = doubleTap
        self.watch = watch
    }

    public var phase: TriggerStateMachine.Phase {
        machine.phase
    }

    /// True while Command is held and the overlay may still show.
    public var isCountingDown: Bool {
        machine.phase.isCountingDown
    }

    /// A copy with another hold delay, used from the next countdown on.
    public func with(delay: Double) -> Self {
        Self(machine: machine.with(delay: delay), paletteTrigger: paletteTrigger, doubleTap: doubleTap, watch: watch)
    }

    /// A copy with another palette trigger. A tap in progress is dropped,
    /// unless the trigger is unchanged.
    public func with(paletteTrigger trigger: PaletteTrigger) -> Self {
        guard trigger != paletteTrigger else {
            return self
        }
        return Self(machine: machine, paletteTrigger: trigger, doubleTap: .init(trigger: trigger), watch: watch)
    }

    /// The state after `input`, and the effects to carry out in order.
    public func updated(with input: Input, clock: KeyClock) -> (state: Self, effects: [Effect]) {
        let update = switch input {
        case let .modifiersChanged(held, time):
            feeding(.modifiersChanged(held), clock).then { $0.tapping(.modifiersChanged(held, time: time), clock) }
        case .keyDown:
            feeding(.keyDown, clock).then { $0.tapping(.otherInput, clock) }
        case let .mouseDown(outside):
            feeding(outside ? .mouseDownOutside : .mouseDown, clock).then { $0.tapping(.otherInput, clock) }
        case .interrupted:
            feeding(.interrupted, clock).then { $0.tapping(.otherInput, clock) }
        case let .countdownEnded(token, held):
            countdownEnded(token: token, held: held, clock)
        case .shownPollTick:
            shownPollTick(clock)
        case .closePalette:
            feeding(.close, clock)
        case .reset:
            feeding(.reset, clock).then { Update($0.with(doubleTap: .init(trigger: $0.paletteTrigger))) }
        }
        return (update.state, update.effects)
    }

    // MARK: - Missed key presses

    /// Re-reads the modifiers and checks for a missed key press before the
    /// timer event, so either can still cancel the countdown. A timer from
    /// an earlier countdown is ignored.
    private func countdownEnded(token: Int, held: HeldModifiers, _ clock: KeyClock) -> Update {
        guard machine.phase == .countingDown(token: token) else {
            return Update(self)
        }
        let reread = feeding(.modifiersChanged(held), clock)
        let checked = keyMissed(clock) ? reread.then { $0.missedKeyDown(.countdown, clock) } : reread
        return checked.then { $0.feeding(.timerFired(token: token), clock) }
    }

    private func shownPollTick(_ clock: KeyClock) -> Update {
        guard machine.phase == .shown, keyMissed(clock) else {
            return Update(self)
        }
        return missedKeyDown(.shownOverlay, clock)
    }

    private func keyMissed(_ clock: KeyClock) -> Bool {
        watch.map(clock.keyWentDown(since:)) ?? false
    }

    private func missedKeyDown(_ moment: MissedKeyMoment, _ clock: KeyClock) -> Update {
        Update(self, [.missedKeyPress(moment)]).then { $0.feeding(.keyDown, clock) }
    }

    // MARK: - Feeding the parts

    private func feeding(_ event: TriggerStateMachine.Event, _ clock: KeyClock) -> Update {
        let (next, action) = machine.updated(with: event)
        let leftShown = machine.phase == .shown && next.phase != .shown
        let arms = switch action {
        case .startTimer, .show: true
        case .none, .cancelTimer, .showPalette, .hide: false
        }
        let state = Self(
            machine: next, paletteTrigger: paletteTrigger, doubleTap: doubleTap,
            watch: arms ? MissedKeyDown(armedAt: clock.now) : watch
        )
        return Update(state, (leftShown ? [.stopShownPoll] : []) + Self.effects(for: action, after: event))
    }

    /// A completed double tap with a missed key press in it (Cmd+Space twice) is dropped.
    private func tapping(_ event: DoubleTapDetector.Event, _ clock: KeyClock) -> Update {
        let (detector, startedAt) = doubleTap.updated(with: event)
        let state = with(doubleTap: detector)
        guard let startedAt else {
            return Update(state)
        }
        guard !clock.keyWentDown(since: MissedKeyDown(armedAt: startedAt)) else {
            return Update(state, [.missedKeyPress(.doubleTap)])
        }
        return state.feeding(.doubleTap, clock)
    }

    private static func effects(
        for action: TriggerStateMachine.Action, after event: TriggerStateMachine.Event
    ) -> [Effect] {
        switch action {
        case let .startTimer(token, delay): [.startCountdown(token: token, delay: delay)]
        case .cancelTimer: [.cancelCountdown]
        case .show: [.startShownPoll, .show]
        case .showPalette: [.showPalette]
        case .hide: [.hide(after: event)]
        case .none: []
        }
    }

    private func with(doubleTap: DoubleTapDetector) -> Self {
        Self(machine: machine, paletteTrigger: paletteTrigger, doubleTap: doubleTap, watch: watch)
    }
}

/// A coordinator state and the effects collected on the way to it.
private struct Update {
    let state: TriggerCoordinator
    let effects: [TriggerCoordinator.Effect]

    init(_ state: TriggerCoordinator, _ effects: [TriggerCoordinator.Effect] = []) {
        self.state = state
        self.effects = effects
    }

    /// Runs `next` on the state and appends its effects.
    func then(_ next: (TriggerCoordinator) -> Update) -> Update {
        let update = next(state)
        return Update(update.state, effects + update.effects)
    }
}
