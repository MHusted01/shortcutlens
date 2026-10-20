import ShortcutLensCore
import Testing

struct TriggerStateMachineTests {
    typealias Machine = TriggerStateMachine

    /// Modifier sets that are not Command alone, each with at least one key held.
    private static let otherModifiers: [HeldModifiers] = [
        .shift, .option, .control,
        [.command, .shift], [.command, .option], [.command, .control],
        [.command, .shift, .option, .control],
        [.shift, .option],
    ]

    /// Every modifier set that includes Command plus at least one other key.
    private static let commandChords: [HeldModifiers] = [
        [.command, .shift], [.command, .option], [.command, .control],
        [.command, .shift, .option, .control],
    ]

    private static func counting() -> (state: Machine, token: Int) {
        let (state, action) = Machine.initial.updated(with: .modifiersChanged(.command))
        guard case let .startTimer(token, _) = action else {
            Issue.record("expected startTimer, got \(action)")
            return (state, -1)
        }
        return (state, token)
    }

    private static func shown() -> Machine {
        let (state, token) = counting()
        return state.updated(with: .timerFired(token: token)).state
    }

    private static func suppressed() -> Machine {
        Machine.initial.updated(with: .modifiersChanged(.shift)).state
    }

    // MARK: - idle

    @Test func startsIdle() {
        #expect(Machine.initial.phase == .idle)
        #expect(Machine.initial.delay == Machine.defaultDelay)
    }

    @Test func commandAloneStartsCountdown() {
        let (state, action) = Machine.initial.updated(with: .modifiersChanged(.command))

        guard case let .countingDown(token) = state.phase else {
            Issue.record("expected countingDown, got \(state.phase)")
            return
        }
        #expect(action == .startTimer(token: token, delay: Machine.defaultDelay))
    }

    @Test(arguments: otherModifiers)
    func otherModifiersFromIdleSuppress(modifiers: HeldModifiers) {
        let (state, action) = Machine.initial.updated(with: .modifiersChanged(modifiers))

        #expect(state.phase == .suppressed)
        #expect(action == .none)
    }

    @Test func noModifiersKeepsIdle() {
        let (state, action) = Machine.initial.updated(with: .modifiersChanged([]))

        #expect(state == Machine.initial)
        #expect(action == .none)
    }

    @Test(arguments: [Machine.Event.keyDown, .mouseDown, .timerFired(token: 0), .reset, .interrupted])
    func idleIgnoresOtherEvents(event: Machine.Event) {
        let (state, action) = Machine.initial.updated(with: event)

        #expect(state == Machine.initial)
        #expect(action == .none)
    }

    @Test func customDelayIsUsed() {
        let machine = Machine(delay: 0.25)
        let (_, action) = machine.updated(with: .modifiersChanged(.command))

        guard case let .startTimer(_, delay) = action else {
            Issue.record("expected startTimer, got \(action)")
            return
        }
        #expect(delay == 0.25)
    }

    // MARK: - countingDown

    @Test func timerFiringShowsOverlay() {
        let (counting, token) = Self.counting()
        let (state, action) = counting.updated(with: .timerFired(token: token))

        #expect(state.phase == .shown)
        #expect(action == .show)
    }

    @Test func staleTimerIsIgnored() {
        let (counting, token) = Self.counting()
        let (state, action) = counting.updated(with: .timerFired(token: token + 1))

        #expect(state == counting)
        #expect(action == .none)
    }

    @Test func repeatedCommandAloneKeepsCountdown() {
        let (counting, _) = Self.counting()
        let (state, action) = counting.updated(with: .modifiersChanged(.command))

        #expect(state == counting)
        #expect(action == .none)
    }

    @Test func releasingCommandCancelsCountdown() {
        let (counting, _) = Self.counting()
        let (state, action) = counting.updated(with: .modifiersChanged([]))

        #expect(state.phase == .idle)
        #expect(action == .cancelTimer)
    }

    @Test(arguments: otherModifiers)
    func otherModifiersCancelCountdown(modifiers: HeldModifiers) {
        let (counting, _) = Self.counting()
        let (state, action) = counting.updated(with: .modifiersChanged(modifiers))

        #expect(state.phase == .suppressed)
        #expect(action == .cancelTimer)
    }

    @Test(arguments: [Machine.Event.keyDown, .mouseDown, .interrupted])
    func inputCancelsCountdown(event: Machine.Event) {
        let (counting, _) = Self.counting()
        let (state, action) = counting.updated(with: event)

        #expect(state.phase == .suppressed)
        #expect(action == .cancelTimer)
    }

    @Test func resetCancelsCountdown() {
        let (counting, _) = Self.counting()
        let (state, action) = counting.updated(with: .reset)

        #expect(state.phase == .idle)
        #expect(action == .cancelTimer)
    }

    @Test func eachCountdownGetsANewToken() {
        let (first, firstToken) = Self.counting()
        let idle = first.updated(with: .modifiersChanged([])).state
        let (_, action) = idle.updated(with: .modifiersChanged(.command))

        guard case let .startTimer(secondToken, _) = action else {
            Issue.record("expected startTimer, got \(action)")
            return
        }
        #expect(secondToken != firstToken)
    }

    @Test func timerFromCancelledCountdownDoesNotShowLaterOne() {
        let (first, oldToken) = Self.counting()
        let idle = first.updated(with: .modifiersChanged([])).state
        let second = idle.updated(with: .modifiersChanged(.command)).state
        let (state, action) = second.updated(with: .timerFired(token: oldToken))

        #expect(state == second)
        #expect(action == .none)
    }

    // MARK: - shown

    @Test func releasingCommandHidesOverlay() {
        let (state, action) = Self.shown().updated(with: .modifiersChanged([]))

        #expect(state.phase == .idle)
        #expect(action == .hide)
    }

    @Test(arguments: [HeldModifiers.shift, .option, .control, [.shift, .option]])
    func releasingCommandWithOthersHeldHides(modifiers: HeldModifiers) {
        let (state, action) = Self.shown().updated(with: .modifiersChanged(modifiers))

        #expect(state.phase == .suppressed)
        #expect(action == .hide)
    }

    @Test(arguments: [HeldModifiers.command] + commandChords)
    func shownStaysWhileCommandHeld(modifiers: HeldModifiers) {
        let shown = Self.shown()
        let (state, action) = shown.updated(with: .modifiersChanged(modifiers))

        #expect(state == shown)
        #expect(action == .none)
    }

    @Test(arguments: [Machine.Event.keyDown, .interrupted])
    func keyPressOrInterruptionHidesOverlay(event: Machine.Event) {
        let (state, action) = Self.shown().updated(with: event)

        #expect(state.phase == .suppressed)
        #expect(action == .hide)
    }

    @Test(arguments: [Machine.Event.mouseDown, .timerFired(token: 0)])
    func shownIgnoresClicksAndTimers(event: Machine.Event) {
        let shown = Self.shown()
        let (state, action) = shown.updated(with: event)

        #expect(state == shown)
        #expect(action == .none)
    }

    @Test func resetHidesOverlay() {
        let (state, action) = Self.shown().updated(with: .reset)

        #expect(state.phase == .idle)
        #expect(action == .hide)
    }

    // MARK: - suppressed

    @Test func releasingAllModifiersEndsSuppression() {
        let (state, action) = Self.suppressed().updated(with: .modifiersChanged([]))

        #expect(state.phase == .idle)
        #expect(action == .none)
    }

    @Test(arguments: [HeldModifiers.command] + otherModifiers)
    func suppressionHoldsWhileAnyModifierHeld(modifiers: HeldModifiers) {
        let suppressed = Self.suppressed()
        let (state, action) = suppressed.updated(with: .modifiersChanged(modifiers))

        #expect(state == suppressed)
        #expect(action == .none)
    }

    @Test(arguments: [Machine.Event.keyDown, .mouseDown, .timerFired(token: 0), .interrupted])
    func suppressedIgnoresInput(event: Machine.Event) {
        let suppressed = Self.suppressed()
        let (state, action) = suppressed.updated(with: event)

        #expect(state == suppressed)
        #expect(action == .none)
    }

    @Test func resetEndsSuppression() {
        let (state, action) = Self.suppressed().updated(with: .reset)

        #expect(state.phase == .idle)
        #expect(action == .none)
    }

    // MARK: - sequences

    @Test func copyShortcutNeverShowsOverlay() {
        let events: [Machine.Event] = [
            .modifiersChanged(.command), .keyDown, .modifiersChanged([]),
        ]
        let actions = Self.run(events)

        #expect(!actions.contains(.show))
        #expect(actions.last == Machine.Action.none)
    }

    @Test func interruptionNeverShowsOverlay() {
        // Fallback path: an app activation or Space change without a key event.
        let events: [Machine.Event] = [
            .modifiersChanged(.command), .interrupted, .modifiersChanged([]),
        ]
        let actions = Self.run(events)

        #expect(!actions.contains(.show))
        #expect(actions == [.startTimer(token: 0, delay: Machine.defaultDelay), .cancelTimer, .none])
    }

    @Test func commandShiftThenShiftReleasedDoesNotRestart() {
        let events: [Machine.Event] = [
            .modifiersChanged(.command), .modifiersChanged([.command, .shift]),
            .modifiersChanged(.command),
        ]
        let actions = Self.run(events)

        #expect(actions.filter(\.startsTimer).count == 1)
    }

    @Test func holdShowReleaseHoldAgainShowsAgain() {
        var machine = Machine.initial
        var shows = 0
        for _ in 0 ..< 2 {
            let (counting, start) = machine.updated(with: .modifiersChanged(.command))
            guard case let .startTimer(token, _) = start else {
                Issue.record("expected startTimer, got \(start)")
                return
            }
            let (shown, show) = counting.updated(with: .timerFired(token: token))
            shows += show == .show ? 1 : 0
            machine = shown.updated(with: .modifiersChanged([])).state
        }

        #expect(shows == 2)
        #expect(machine.phase == .idle)
    }

    @Test func newDelayKeepsTheRunningCountdown() {
        let (counting, _) = Machine.initial.updated(with: .modifiersChanged(.command))

        let changed = counting.with(delay: 0.3)

        #expect(changed.delay == 0.3)
        #expect(changed.phase == counting.phase)
        #expect(changed.updated(with: .timerFired(token: 0)).action == .show)
    }

    @Test func newDelayAppliesToTheNextCountdown() {
        let (_, action) = Machine.initial.with(delay: 0.3).updated(with: .modifiersChanged(.command))

        #expect(action == .startTimer(token: 0, delay: 0.3))
    }

    private static func run(_ events: [Machine.Event]) -> [Machine.Action] {
        var machine = Machine.initial
        var actions: [Machine.Action] = []
        for event in events {
            let (next, action) = machine.updated(with: event)
            machine = next
            actions.append(action)
        }
        return actions
    }
}

private extension TriggerStateMachine.Action {
    var startsTimer: Bool {
        if case .startTimer = self {
            return true
        }
        return false
    }
}

struct HeldModifiersTests {
    @Test func commandAloneIsOnlyCommand() {
        #expect(HeldModifiers.command.isCommandAlone)
        #expect(!HeldModifiers([.command, .shift]).isCommandAlone)
        #expect(!HeldModifiers.shift.isCommandAlone)
        #expect(!HeldModifiers().isCommandAlone)
    }
}

struct TriggerPhaseTests {
    @Test func onlyACountdownIsCountingDown() {
        let phases: [TriggerStateMachine.Phase] = [.idle, .countingDown(token: 1), .shown, .suppressed, .palette]

        #expect(phases.map(\.isCountingDown) == [false, true, false, false, false])
    }
}
