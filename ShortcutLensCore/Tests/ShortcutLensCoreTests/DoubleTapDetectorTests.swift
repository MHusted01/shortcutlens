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

    @Test func twoQuickTapsAreDetectedOnSecondRelease() {
        let result = Self.detections([Self.press(0), Self.release(0.1), Self.press(0.3), Self.release(0.4)])

        #expect(result == [false, false, false, true])
    }

    /// The start lets the caller check for key presses the monitors missed.
    @Test func reportsWhenTheFirstPressStarted() {
        let result = Self.starts([Self.press(5), Self.release(5.1), Self.press(5.3), Self.release(5.4)])

        #expect(result == [nil, nil, nil, 5])
    }

    @Test func startOfLaterPairIsItsOwnFirstPress() {
        let result = Self.starts([
            Self.press(0), Self.release(0.1), Self.press(1), Self.release(1.1), Self.press(1.3), Self.release(1.4),
        ])

        #expect(result.last == 1)
    }

    @Test func tapsAtTheIntervalLimitStillCount() {
        let limit = Detector.interval
        let result = Self.detections([
            Self.press(0), Self.release(limit), Self.press(2 * limit), Self.release(3 * limit),
        ])

        #expect(result.last == true)
    }

    @Test func longFirstPressIsNoTap() {
        let result = Self.detections([Self.press(0), Self.release(0.5), Self.press(0.6), Self.release(0.7)])

        #expect(result.last == false)
    }

    @Test func longGapBetweenTapsIsNoDoubleTap() {
        let result = Self.detections([Self.press(0), Self.release(0.1), Self.press(0.5), Self.release(0.6)])

        #expect(result.last == false)
    }

    @Test func longSecondPressIsNoDoubleTap() {
        let result = Self.detections([Self.press(0), Self.release(0.1), Self.press(0.3), Self.release(0.7)])

        #expect(result.last == false)
    }

    /// A tap that was too slow to be a second tap can still be the first one.
    @Test func lateTapStartsANewPair() {
        let result = Self.detections([
            Self.press(0), Self.release(0.1), Self.press(1), Self.release(1.1), Self.press(1.3), Self.release(1.4),
        ])

        #expect(result == [false, false, false, false, false, true])
    }

    @Test func otherInputBetweenTapsCancels() {
        let result = Self.detections([
            Self.press(0), Self.release(0.1), .otherInput, Self.press(0.2), Self.release(0.3),
        ])

        #expect(result.last == false)
    }

    @Test func otherInputDuringPressCancels() {
        let result = Self.detections([
            Self.press(0), Self.release(0.1), Self.press(0.2), .otherInput, Self.release(0.3),
        ])

        #expect(result.last == false)
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

    @Test func otherModifierBetweenTapsCancels() {
        let result = Self.detections([
            Self.press(0), Self.release(0.1),
            .modifiersChanged(.shift, time: 0.15), Self.release(0.2),
            Self.press(0.25), Self.release(0.3),
        ])

        #expect(result.last == false)
    }

    @Test func tripleTapIsDetectedOnce() {
        let result = Self.detections([
            Self.press(0), Self.release(0.1), Self.press(0.2), Self.release(0.3), Self.press(0.4), Self.release(0.5),
        ])

        #expect(result == [false, false, false, true, false, false])
    }

    @Test func repeatedCommandReportDuringPressIsIgnored() {
        let result = Self.detections([
            Self.press(0), Self.press(0.05), Self.release(0.1), Self.press(0.3), Self.release(0.4),
        ])

        #expect(result.last == true)
    }

    @Test func otherInputWhileIdleChangesNothing() {
        let (state, startedAt) = Detector.initial.updated(with: .otherInput)

        #expect(state == .initial)
        #expect(startedAt == nil)
    }
}
