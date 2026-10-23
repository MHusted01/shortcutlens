import ShortcutLensCore
import Testing

/// The palette side of the coordinator: the double tap reaches the state
/// machine, a missed key press drops it, and closing works.
struct TriggerCoordinatorPaletteTests {
    typealias Coordinator = TriggerCoordinator

    /// `modifier` tapped at 0 and at 0.2; the second release is read with
    /// the last key press at `lastKeyDown`.
    private static func doubleTap(
        _ modifier: HeldModifiers, on state: Coordinator = .initial, lastKeyDown: Double? = nil
    ) -> (state: Coordinator, effects: [Coordinator.Effect]) {
        state.tapped(modifier, at: 0)
            .fed([(.modifiersChanged(modifier, time: 0.2), 0.2)])
            .updated(with: .modifiersChanged([], time: 0.3), clock: .at(0.3, lastKeyDown: lastKeyDown))
    }

    private static func palette() -> Coordinator {
        doubleTap(.command).state
    }

    // MARK: - Opening

    /// The second release ends the countdown before the double tap opens the palette.
    @Test func commandDoubleTapOpensPalette() {
        let (state, effects) = Self.doubleTap(.command)

        #expect(state.phase == .palette)
        #expect(effects == [.cancelCountdown, .showPalette])
    }

    @Test(arguments: [(PaletteTrigger.option, HeldModifiers.option), (.control, .control)])
    func chosenTriggerOpensPalette(trigger: PaletteTrigger, modifier: HeldModifiers) {
        let (state, effects) = Self.doubleTap(modifier, on: Coordinator.initial.with(paletteTrigger: trigger))

        #expect(state.phase == .palette)
        #expect(effects == [.showPalette])
    }

    @Test func otherModifierDoesNotOpenPalette() {
        let (state, _) = Self.doubleTap(.command, on: Coordinator.initial.with(paletteTrigger: .option))

        #expect(state.phase == .idle)
    }

    @Test func offNeverOpensPalette() {
        let (state, _) = Self.doubleTap(.command, on: Coordinator.initial.with(paletteTrigger: .off))

        #expect(state.phase == .idle)
    }

    /// A double tap with a key press the monitors missed (Cmd+Space twice).
    @Test func missedKeyDuringDoubleTapIsDropped() {
        let (state, effects) = Self.doubleTap(.command, lastKeyDown: 0.15)

        #expect(state.phase == .idle)
        #expect(effects == [.cancelCountdown, .missedKeyPress(.doubleTap)])
    }

    @Test func keyBeforeDoubleTapIsIgnored() {
        let (state, _) = Self.doubleTap(.command, lastKeyDown: -1)

        #expect(state.phase == .palette)
    }

    // MARK: - Broken taps

    @Test(arguments: [Coordinator.Input.keyDown, .mouseDown(outside: true), .interrupted])
    func inputBetweenTapsBreaksDoubleTap(input: Coordinator.Input) {
        let state = Coordinator.initial.tapped(.command, at: 0)
            .fed([(input, 0.15)])
            .tapped(.command, at: 0.2)

        #expect(state.phase != .palette)
    }

    @Test func changingTriggerDropsTapInProgress() {
        let state = Coordinator.initial.tapped(.command, at: 0)
            .with(paletteTrigger: .option)
            .with(paletteTrigger: .command)
            .tapped(.command, at: 0.2)

        #expect(state.phase == .idle)
    }

    @Test func sameTriggerKeepsTapInProgress() {
        let state = Coordinator.initial.tapped(.command, at: 0)
            .with(paletteTrigger: .command)
            .tapped(.command, at: 0.2)

        #expect(state.phase == .palette)
    }

    @Test func resetDropsTapInProgress() {
        let state = Coordinator.initial.tapped(.command, at: 0)
            .fed([(.reset, 0.15)])
            .tapped(.command, at: 0.2)

        #expect(state.phase == .idle)
    }

    // MARK: - Closing

    @Test func closePaletteHides() {
        let (state, effects) = Self.palette().updated(with: .closePalette, clock: .at(1))

        #expect(state.phase == .idle)
        #expect(effects == [.hide(after: .close)])
    }

    @Test func clickOutsideClosesPalette() {
        let (state, effects) = Self.palette().updated(with: .mouseDown(outside: true), clock: .at(1))

        #expect(state.phase == .idle)
        #expect(effects == [.hide(after: .mouseDownOutside)])
    }

    @Test func typingInPaletteKeepsIt() {
        let (state, effects) = Self.palette().updated(with: .keyDown, clock: .at(1, lastKeyDown: 0.9))

        #expect(state.phase == .palette)
        #expect(effects.isEmpty)
    }
}
