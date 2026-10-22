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
    @Test(arguments: [.keyDown, .mouseDown, .timerFired(token: 0)] as [Machine.Event])
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

    // MARK: - Palette events outside the palette

    @Test func closeOutsidePaletteChangesNothing() {
        let others = [Machine.initial, Self.counting().state, Self.shown(), Self.suppressed()]

        for machine in others {
            let (state, action) = machine.updated(with: .close)

            #expect(state == machine)
            #expect(action == .none)
        }
    }
}
