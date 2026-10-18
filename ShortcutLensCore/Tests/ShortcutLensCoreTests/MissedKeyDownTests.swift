import ShortcutLensCore
import Testing

struct MissedKeyDownTests {
    private let watch = MissedKeyDown(armedAt: 100)

    @Test func keyAfterArmingCounts() {
        // Now 101, key 0.4 s ago -> pressed at 100.6.
        #expect(watch.keyWentDown(now: 101, secondsSinceLastKeyDown: 0.4))
    }

    @Test func keyBeforeArmingIsIgnored() {
        // Now 101, key 1.5 s ago -> pressed at 99.5.
        #expect(!watch.keyWentDown(now: 101, secondsSinceLastKeyDown: 1.5))
    }

    @Test func keyExactlyAtArmingIsIgnored() {
        #expect(!watch.keyWentDown(now: 101, secondsSinceLastKeyDown: 1))
    }

    @Test func noKeySinceBootIsIgnored() {
        #expect(!watch.keyWentDown(now: 101, secondsSinceLastKeyDown: .greatestFiniteMagnitude))
    }

    @Test(arguments: [Double.nan, -1, .infinity])
    func invalidReadingIsIgnored(seconds: Double) {
        #expect(!watch.keyWentDown(now: 101, secondsSinceLastKeyDown: seconds))
    }
}
