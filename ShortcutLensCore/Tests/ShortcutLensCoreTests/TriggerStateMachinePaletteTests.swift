import ShortcutLensCore
import Testing

/// Palette mode: entered by a double tap of Command, left only by an explicit
/// close or an interruption.
struct TriggerStateMachinePaletteTests {
    typealias Machine = TriggerStateMachine

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

    private static func palette() -> Machine {
        Machine.initial.updated(with: .doubleTap).state
    }

    // MARK: - Entering

    @Test func doubleTapFromIdleOpensPalette() {
        let (state, action) = Machine.initial.updated(with: .doubleTap)

        #expect(state.phase == .palette)
        #expect(action == .showPalette)
    }

    /// The detector reports the double tap after the second release, which has
    /// already ended the countdown; the full sequence must open the palette.
    @Test func tapTapSequenceOpensPalette() {
        let taps: [Machine.Event] = [
            .modifiersChanged(.command), .modifiersChanged([]),
            .modifiersChanged(.command), .modifiersChanged([]),
        ]
        let afterTaps = taps.reduce(Machine.initial) { $0.updated(with: $1).state }

        let (state, action) = afterTaps.updated(with: .doubleTap)

        #expect(state.phase == .palette)
        #expect(action == .showPalette)
    }

    @Test func doubleTapIsIgnoredOutsideIdle() {
        let others = [Self.counting().state, Self.shown(), Self.suppressed(), Self.palette()]

        for machine in others {
            let (state, action) = machine.updated(with: .doubleTap)

            #expect(state == machine)
            #expect(action == .none)
        }
    }

    // MARK: - Staying open

    @Test(arguments: [[], .command, [.command, .shift], .shift] as [HeldModifiers])
    func paletteIgnoresModifiers(modifiers: HeldModifiers) {
        let (state, action) = Self.palette().updated(with: .modifiersChanged(modifiers))

        #expect(state.phase == .palette)
        #expect(action == .none)
    }

    /// Typed keys and clicks on the panel belong to the palette, and a late
    /// countdown timer must not change it.
    @Test(arguments: [.keyDown, .mouseDown, .timerFired(token: 0), .timerFired(token: 99)] as [Machine.Event])
    func paletteIgnoresInput(event: Machine.Event) {
        let (state, action) = Self.palette().updated(with: event)

        #expect(state.phase == .palette)
        #expect(action == .none)
    }

    // MARK: - Closing

    @Test(arguments: [.mouseDownOutside, .interrupted, .close, .reset] as [Machine.Event])
    func paletteCloses(event: Machine.Event) {
        let (state, action) = Self.palette().updated(with: event)

        #expect(state.phase == .idle)
        #expect(action == .hide)
    }

    @Test func holdWorksAgainAfterPaletteCloses() {
        let closed = Self.palette().updated(with: .close).state

        let (state, action) = closed.updated(with: .modifiersChanged(.command))

        guard case let .countingDown(token) = state.phase else {
            Issue.record("expected countingDown, got \(state.phase)")
            return
        }
        #expect(action == .startTimer(token: token, delay: Machine.defaultDelay))
    }

    // MARK: - New events outside the palette

    @Test func clickOutsideCancelsCountdownLikeAnyClick() {
        let (state, action) = Self.counting().state.updated(with: .mouseDownOutside)

        #expect(state.phase == .suppressed)
        #expect(action == .cancelTimer)
    }

    @Test func clickOutsideKeepsHoldOverlayShown() {
        let (state, action) = Self.shown().updated(with: .mouseDownOutside)

        #expect(state.phase == .shown)
        #expect(action == .none)
    }

    @Test func closeOutsidePaletteChangesNothing() {
        let others = [Machine.initial, Self.counting().state, Self.shown(), Self.suppressed()]

        for machine in others {
            let (state, action) = machine.updated(with: .close)

            #expect(state == machine)
            #expect(action == .none)
        }
    }
}
