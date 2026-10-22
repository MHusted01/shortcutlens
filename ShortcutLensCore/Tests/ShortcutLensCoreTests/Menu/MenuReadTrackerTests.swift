import ShortcutLensCore
import Testing

struct MenuReadTrackerTests {
    typealias Tracker = MenuReadTracker<Int, String>

    private static let withSystem = AppSettings.defaults.with(showsSystemShortcuts: true)
    private static let withoutSystem = AppSettings.defaults.with(showsSystemShortcuts: false)

    /// A tracker with a read "r" running for app 1, started in a new generation.
    private static func reading(settings: AppSettings = withSystem) -> Tracker {
        Tracker(settings: settings).nextGeneration().started("r", for: 1)
    }

    @Test func reusesTheReadRunningForTheSameApp() {
        let tracker = Self.reading()

        #expect(tracker.running(for: 1) == "r")
        #expect(tracker.running(for: 2) == nil)
    }

    @Test func showsAndCachesACurrentRead() {
        let tracker = Self.reading()

        let (next, outcome) = tracker
            .finishing(1, stamp: tracker.stamp, settings: Self.withSystem, appTerminated: false)

        #expect(outcome == .init(caches: true, next: .show))
        #expect(next.running(for: 1) == nil)
    }

    @Test func cachesButDoesNotShowAReadFromAnOlderGeneration() {
        let tracker = Self.reading()
        let stamp = tracker.stamp

        let (next, outcome) = tracker.nextGeneration()
            .finishing(1, stamp: stamp, settings: Self.withSystem, appTerminated: false)

        #expect(outcome == .init(caches: true, next: .none))
        #expect(next.running(for: 1) == nil)
    }

    @Test func doesNotCacheTheReadOfAnAppThatQuit() {
        let tracker = Self.reading()

        let (_, outcome) = tracker.finishing(1, stamp: tracker.stamp, settings: Self.withSystem, appTerminated: true)

        #expect(outcome == .init(caches: false, next: .show))
    }

    @Test func keepsTheReadOfAnotherAppInFlight() {
        let tracker = Self.reading()

        let (next, _) = tracker.finishing(2, stamp: tracker.stamp, settings: Self.withSystem, appTerminated: false)

        #expect(next.running(for: 1) == "r")
    }

    @Test func settingsThatChangeTheMenusDropTheCacheAndTheRunningRead() {
        let (next, dropsCache) = Self.reading().applying(Self.withSystem.with(maxMenuDepth: 2))

        #expect(dropsCache)
        #expect(next.running(for: 1) == nil)
    }

    @Test func turningSystemShortcutsOnRestartsReadsButKeepsTheCache() {
        let (next, dropsCache) = Self.reading(settings: Self.withoutSystem).applying(Self.withSystem)

        #expect(!dropsCache)
        #expect(next.running(for: 1) == nil)
    }

    @Test func turningSystemShortcutsOffKeepsTheRunningRead() {
        let (next, dropsCache) = Self.reading().applying(Self.withoutSystem)

        #expect(!dropsCache)
        #expect(next.running(for: 1) == "r")
    }

    @Test func aReadWithOlderSettingsIsReadAgainNotCached() {
        let tracker = Self.reading(settings: Self.withoutSystem)
        let stamp = tracker.stamp
        let (applied, _) = tracker.applying(Self.withSystem)

        let (_, outcome) = applied.finishing(1, stamp: stamp, settings: Self.withoutSystem, appTerminated: false)

        #expect(outcome == .init(caches: false, next: .readAgain))
    }

    @Test func aLayoutSwitchStopsReusingTheRunningRead() throws {
        let tracker = Self.reading()
        let stamp = tracker.stamp

        let changed = try #require(tracker.changingLayout())
        let (_, outcome) = changed.finishing(1, stamp: stamp, settings: Self.withSystem, appTerminated: false)

        #expect(changed.running(for: 1) == nil)
        #expect(outcome == .init(caches: false, next: .readAgain))
    }

    @Test func aLayoutSwitchChangesNothingWithoutSystemShortcuts() {
        #expect(Self.reading(settings: Self.withoutSystem).changingLayout() == nil)
    }

    @Test func aStaleReadOfAnOlderGenerationIsNeitherShownNorReadAgain() throws {
        let tracker = Self.reading()
        let stamp = tracker.stamp

        let changed = try #require(tracker.changingLayout()).nextGeneration()
        let (_, outcome) = changed.finishing(1, stamp: stamp, settings: Self.withSystem, appTerminated: false)

        #expect(outcome == .init(caches: false, next: .none))
    }
}
