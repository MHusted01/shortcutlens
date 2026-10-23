import ShortcutLensCore
import Testing

/// The overlay side of the coordinator: countdown, missed key presses and the
/// shown-overlay poll. The palette side is in `TriggerCoordinatorPaletteTests`.
struct TriggerCoordinatorTests {
    typealias Coordinator = TriggerCoordinator

    // MARK: - Countdown

    @Test func commandAloneStartsCountdown() {
        let (state, effects) = Coordinator.initial.updated(
            with: .modifiersChanged(.command, time: 0), clock: .at(0)
        )

        #expect(state.isCountingDown)
        #expect(effects == [.startCountdown(token: 0, delay: TriggerStateMachine.defaultDelay)])
    }

    @Test func delayAppliesToNextCountdown() {
        let (_, effects) = Coordinator.initial.with(delay: 0.5).updated(
            with: .modifiersChanged(.command, time: 0), clock: .at(0)
        )

        #expect(effects == [.startCountdown(token: 0, delay: 0.5)])
    }

    @Test func countdownEndShowsOverlayAndStartsPoll() {
        let (state, effects) = Coordinator.countingDown().updated(
            with: .countdownEnded(token: 0, held: .command), clock: .at(1)
        )

        #expect(state.phase == .shown)
        #expect(effects == [.startShownPoll, .show])
    }

    @Test(arguments: [Coordinator.Input.keyDown, .mouseDown(outside: true), .mouseDown(outside: false), .interrupted])
    func otherInputCancelsCountdown(input: Coordinator.Input) {
        let (state, effects) = Coordinator.countingDown().updated(with: input, clock: .at(0.5))

        #expect(state.phase == .suppressed)
        #expect(effects == [.cancelCountdown])
    }

    /// A release the monitors missed is caught by re-reading the modifiers.
    @Test func countdownEndWithCommandReleasedDoesNotShow() {
        let (state, effects) = Coordinator.countingDown().updated(
            with: .countdownEnded(token: 0, held: []), clock: .at(1)
        )

        #expect(state.phase == .idle)
        #expect(effects == [.cancelCountdown])
    }

    /// Cmd+Space never reaches the monitors; the key clock reveals it.
    @Test func keyMissedDuringCountdownCancelsIt() {
        let (state, effects) = Coordinator.countingDown().updated(
            with: .countdownEnded(token: 0, held: .command), clock: .at(1, lastKeyDown: 0.5)
        )

        #expect(state.phase == .suppressed)
        #expect(effects == [.missedKeyPress(.countdown), .cancelCountdown])
    }

    @Test func keyBeforeCountdownStartedIsIgnored() {
        let (state, _) = Coordinator.countingDown().updated(
            with: .countdownEnded(token: 0, held: .command), clock: .at(1, lastKeyDown: -0.5)
        )

        #expect(state.phase == .shown)
    }

    @Test func staleCountdownEndIsIgnored() {
        let state = Coordinator.countingDown()

        let (next, effects) = state.updated(with: .countdownEnded(token: 7, held: []), clock: .at(1, lastKeyDown: 0.5))

        #expect(next == state)
        #expect(effects.isEmpty)
    }

    // MARK: - Shown

    @Test func releasingCommandHidesAndStopsPoll() {
        let (state, effects) = Coordinator.shown().updated(with: .modifiersChanged([], time: 2), clock: .at(2))

        #expect(state.phase == .idle)
        #expect(effects == [.stopShownPoll, .hide(after: .modifiersChanged([]))])
    }

    @Test func clickOnShownOverlayKeepsIt() {
        let (state, effects) = Coordinator.shown().updated(with: .mouseDown(outside: false), clock: .at(2))

        #expect(state.phase == .shown)
        #expect(effects.isEmpty)
    }

    @Test func pollWithoutKeyDoesNothing() {
        let (state, effects) = Coordinator.shown().updated(with: .shownPollTick, clock: .at(2))

        #expect(state.phase == .shown)
        #expect(effects.isEmpty)
    }

    @Test func pollFindsMissedKeyAndHides() {
        let (state, effects) = Coordinator.shown().updated(with: .shownPollTick, clock: .at(2, lastKeyDown: 1.5))

        #expect(state.phase == .suppressed)
        #expect(effects == [.missedKeyPress(.shownOverlay), .stopShownPoll, .hide(after: .keyDown)])
    }

    /// The poll watches from the moment the overlay appeared, not from the
    /// start of the countdown.
    @Test func pollIgnoresKeyBeforeOverlayShowed() {
        let (state, effects) = Coordinator.shown().updated(with: .shownPollTick, clock: .at(2, lastKeyDown: 0.9))

        #expect(state.phase == .shown)
        #expect(effects.isEmpty)
    }

    @Test func pollWhenNotShownIsIgnored() {
        let (state, effects) = Coordinator.countingDown().updated(
            with: .shownPollTick, clock: .at(0.5, lastKeyDown: 0.4)
        )

        #expect(state.isCountingDown)
        #expect(effects.isEmpty)
    }

    // MARK: - Reset

    @Test func resetWhileShownHidesAndStopsPoll() {
        let (state, effects) = Coordinator.shown().updated(with: .reset, clock: .at(2))

        #expect(state.phase == .idle)
        #expect(effects == [.stopShownPoll, .hide(after: .reset)])
    }

    @Test func resetWhileCountingDownCancelsCountdown() {
        let (state, effects) = Coordinator.countingDown().updated(with: .reset, clock: .at(0.5))

        #expect(state.phase == .idle)
        #expect(effects == [.cancelCountdown])
    }
}
