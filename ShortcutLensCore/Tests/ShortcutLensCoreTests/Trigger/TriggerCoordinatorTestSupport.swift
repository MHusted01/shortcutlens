import ShortcutLensCore

extension KeyClock {
    /// A reading at `now`, with the last key press at `lastKeyDown` (none when nil).
    static func at(_ now: Double, lastKeyDown: Double? = nil) -> Self {
        KeyClock(now: now, secondsSinceLastKeyDown: lastKeyDown.map { now - $0 } ?? .greatestFiniteMagnitude)
    }
}

extension TriggerCoordinator {
    /// The state after `inputs`, each read at its own time with no key press.
    func fed(_ inputs: [(Input, Double)]) -> Self {
        inputs.reduce(self) { state, step in
            state.updated(with: step.0, clock: .at(step.1)).state
        }
    }

    /// Command held at time 0: counting down with the first token.
    static func countingDown() -> Self {
        initial.fed([(.modifiersChanged(.command, time: 0), 0)])
    }

    /// The overlay shown by the first countdown, ended at time 1.
    static func shown() -> Self {
        countingDown().fed([(.countdownEnded(token: 0, held: .command), 1)])
    }

    /// `modifier` pressed at `time` and released 0.1 s later.
    func tapped(_ modifier: HeldModifiers, at time: Double) -> Self {
        fed([(.modifiersChanged(modifier, time: time), time), (.modifiersChanged([], time: time + 0.1), time + 0.1)])
    }
}
