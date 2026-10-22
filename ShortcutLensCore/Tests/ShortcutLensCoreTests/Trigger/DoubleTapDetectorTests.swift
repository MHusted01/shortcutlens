import ShortcutLensCore
import Testing

struct DoubleTapDetectorTests {
    typealias Detector = DoubleTapDetector
    typealias Event = DoubleTapDetector.Event

    private static func press(_ time: Double) -> Event {
        .modifiersChanged(.command, time: time)
    }

    private static func release(_ time: Double) -> Event {
        .modifiersChanged([], time: time)
    }

    /// Feeds `events` in order and returns when the double tap each one
    /// completed started, or nil.
    private static func starts(_ events: [Event]) -> [Double?] {
        var detector = Detector.initial
        return events.map { event in
            let (state, startedAt) = detector.updated(with: event)
            detector = state
            return startedAt
        }
    }

    /// Feeds `events` in order and returns whether each one completed a double tap.
    private static func detections(_ events: [Event]) -> [Bool] {
        starts(events).map { $0 != nil }
    }

    /// The start lets the caller check for key presses the monitors missed.
    @Test func reportsTheFirstPressOnTheSecondRelease() {
        let result = Self.starts([Self.press(5), Self.release(5.1), Self.press(5.3), Self.release(5.4)])

        #expect(result == [nil, nil, nil, 5])
    }

    @Test func tapsAtTheIntervalLimitStillCount() {
        let limit = Detector.interval
        let result = Self.detections([
            Self.press(0), Self.release(limit), Self.press(2 * limit), Self.release(3 * limit),
        ])

        #expect(result.last == true)
    }

    /// Press, release, press, release: a long first press, a long gap, a long second press.
    @Test(arguments: [[0, 0.5, 0.6, 0.7], [0, 0.1, 0.5, 0.6], [0, 0.1, 0.3, 0.7]])
    func slowPressOrGapIsNoDoubleTap(times: [Double]) {
        let events = times.enumerated().map { index, time in
            index.isMultiple(of: 2) ? Self.press(time) : Self.release(time)
        }

        #expect(!Self.detections(events).contains(true))
    }

    /// A tap that was too slow to be a second tap can still be the first one.
    @Test func lateTapStartsANewPair() {
        let result = Self.starts([
            Self.press(0), Self.release(0.1), Self.press(1), Self.release(1.1), Self.press(1.3), Self.release(1.4),
        ])

        #expect(result == [nil, nil, nil, nil, nil, 1])
    }

    /// Two quick taps with a key press, click or other modifier in between,
    /// or during the second press.
    @Test(arguments: [
        [press(0), release(0.1), .otherInput, press(0.2), release(0.3)],
        [press(0), release(0.1), press(0.2), .otherInput, release(0.3)],
        [press(0), release(0.1), .modifiersChanged(.shift, time: 0.15), release(0.2), press(0.25), release(0.3)],
    ])
    func otherInputCancelsTheDoubleTap(events: [Event]) {
        #expect(!Self.detections(events).contains(true))
    }

    @Test(arguments: [.shift, [.command, .shift], [.command, .option], .control] as [HeldModifiers])
    func otherModifierDuringPressCancels(modifiers: HeldModifiers) {
        let result = Self.detections([
            Self.press(0), Self.release(0.1), Self.press(0.2),
            .modifiersChanged(modifiers, time: 0.25), Self.release(0.3),
        ])

        #expect(result.last == false)
    }

    /// Going from Cmd+Shift back to Cmd is not a fresh Command press.
    @Test func commandLeftOverFromChordIsNoTap() {
        let result = Self.detections([
            Self.press(0), Self.release(0.1),
            .modifiersChanged([.command, .shift], time: 0.15), Self.press(0.2), Self.release(0.25),
            Self.press(0.3), Self.release(0.35),
        ])

        #expect(result == [false, false, false, false, false, false, false])
    }

    /// Cmd+C, then the other Command key reports Command again: the press
    /// that ends is still part of the shortcut.
    @Test func commandHeldThroughAKeyPressIsNoTap() {
        let result = Self.detections([
            Self.press(0), .otherInput, Self.press(0.05), Self.release(0.1), Self.press(0.2), Self.release(0.3),
        ])

        #expect(!result.contains(true))
    }

    @Test func releasingEveryModifierAfterAChordAllowsADoubleTap() {
        let result = Self.detections([
            Self.press(0), .modifiersChanged([.command, .shift], time: 0.05), Self.release(0.1),
            Self.press(0.5), Self.release(0.6), Self.press(0.7), Self.release(0.8),
        ])

        #expect(result.last == true)
    }

    @Test func tripleTapIsDetectedOnce() {
        let result = Self.detections([
            Self.press(0), Self.release(0.1), Self.press(0.2), Self.release(0.3), Self.press(0.4), Self.release(0.5),
        ])

        #expect(result == [false, false, false, true, false, false])
    }

    /// Pressing the other Command key reports Command again; the press goes on.
    @Test func repeatedReportDuringTheSecondPressKeepsThePair() {
        let result = Self.starts([
            Self.press(0), Self.release(0.1), Self.press(0.2), Self.press(0.25), Self.release(0.3),
        ])

        #expect(result.last == 0)
    }

    @Test func repeatedReportDoesNotRestartThePress() {
        let result = Self.detections([
            Self.press(0), Self.press(0.3), Self.release(0.4), Self.press(0.5), Self.release(0.6),
        ])

        #expect(!result.contains(true))
    }

    /// Feeds `events` to a detector for `trigger`.
    private static func detections(_ events: [Event], trigger: PaletteTrigger) -> [Bool] {
        var detector = Detector(trigger: trigger)
        return events.map { event in
            let (state, startedAt) = detector.updated(with: event)
            detector = state
            return startedAt != nil
        }
    }

    private static func taps(_ modifier: HeldModifiers) -> [Event] {
        [
            .modifiersChanged(modifier, time: 0), release(0.1),
            .modifiersChanged(modifier, time: 0.3), release(0.4),
        ]
    }

    @Test(arguments: [(PaletteTrigger.option, HeldModifiers.option), (.control, .control)])
    func otherTriggerDetectsItsModifier(trigger: PaletteTrigger, modifier: HeldModifiers) {
        let result = Self.detections(Self.taps(modifier), trigger: trigger)

        #expect(result == [false, false, false, true])
    }

    @Test(arguments: [
        (PaletteTrigger.option, HeldModifiers.command), (.control, .command), (.command, .option),
    ])
    func triggerIgnoresTapsOfAnotherModifier(trigger: PaletteTrigger, modifier: HeldModifiers) {
        #expect(!Self.detections(Self.taps(modifier), trigger: trigger).contains(true))
    }

    /// Holding Command for the overlay while tapping Option is a chord, not a tap.
    @Test func optionTappedWhileCommandHeldIsNoTap() {
        let result = Self.detections([
            Self.press(0),
            .modifiersChanged([.command, .option], time: 0.05), Self.press(0.1),
            .modifiersChanged([.command, .option], time: 0.15), Self.press(0.2), Self.release(0.25),
        ], trigger: .option)

        #expect(!result.contains(true))
    }

    @Test(arguments: [HeldModifiers.command, .option, .control, .shift])
    func offNeverDetects(modifier: HeldModifiers) {
        #expect(!Self.detections(Self.taps(modifier), trigger: .off).contains(true))
    }

    @Test func defaultDetectorUsesCommand() {
        #expect(Detector.initial == Detector(trigger: .command))
    }

    @Test func otherInputWhileIdleChangesNothing() {
        let (state, startedAt) = Detector.initial.updated(with: .otherInput)

        #expect(state == .initial)
        #expect(startedAt == nil)
    }
}
