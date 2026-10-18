import Foundation
import ShortcutLensCore
import Testing

/// A `SettingsStore` backed by a dictionary.
private final class MemoryStore: SettingsStore {
    var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }
}

struct AppSettingsTests {
    @Test func defaultsMatchTheBuiltInBehaviour() {
        let settings = AppSettings.defaults

        #expect(settings.triggerDelay == TriggerStateMachine.defaultDelay)
        #expect(settings.maxMenuDepth == MenuReader<FakeAXClient>.defaultMaxDepth)
        #expect(!settings.showsDisabledItems)
        #expect(settings.showsSystemShortcuts)
    }

    @Test func clampsTriggerDelayToItsRange() {
        #expect(AppSettings(triggerDelay: 0).triggerDelay == AppSettings.triggerDelayRange.lowerBound)
        #expect(AppSettings(triggerDelay: 9).triggerDelay == AppSettings.triggerDelayRange.upperBound)
        #expect(AppSettings(triggerDelay: 0.5).triggerDelay == 0.5)
    }

    @Test func roundsTriggerDelayToItsStep() {
        #expect(AppSettings(triggerDelay: 0.52).triggerDelay == 0.5)
        #expect(AppSettings(triggerDelay: 0.53).triggerDelay == 0.55)
    }

    @Test func treatsANonFiniteDelayAsTheDefault() {
        #expect(AppSettings(triggerDelay: .nan).triggerDelay == TriggerStateMachine.defaultDelay)
        #expect(AppSettings(triggerDelay: .infinity).triggerDelay == TriggerStateMachine.defaultDelay)
    }

    @Test func clampsMaxMenuDepthToItsRange() {
        #expect(AppSettings(maxMenuDepth: 0).maxMenuDepth == 1)
        #expect(AppSettings(maxMenuDepth: 99).maxMenuDepth == AppSettings.maxMenuDepthRange.upperBound)
        #expect(AppSettings(maxMenuDepth: 3).maxMenuDepth == 3)
    }

    @Test func loadsDefaultsFromAnEmptyStore() {
        #expect(AppSettings(store: MemoryStore()) == .defaults)
    }

    @Test func savesAndLoadsEverySetting() {
        let store = MemoryStore()
        let settings = AppSettings(
            triggerDelay: 0.4, maxMenuDepth: 2, showsDisabledItems: true, showsSystemShortcuts: false
        )

        settings.save(to: store)

        #expect(AppSettings(store: store) == settings)
    }

    /// `UserDefaults` hands numbers back as `NSNumber`; they must still read
    /// as `Double`, `Int` and `Bool`.
    @Test func roundTripsThroughUserDefaults() throws {
        let suite = "dev.shortcutlens.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(
            triggerDelay: 0.65, maxMenuDepth: 3, showsDisabledItems: true, showsSystemShortcuts: false
        )

        settings.save(to: defaults)

        #expect(AppSettings(store: defaults) == settings)
    }

    @Test func clampsValuesLoadedFromTheStore() {
        let store = MemoryStore()
        store.values = [
            AppSettings.Key.triggerDelay: 42.0,
            AppSettings.Key.maxMenuDepth: -3,
        ]

        let settings = AppSettings(store: store)

        #expect(settings.triggerDelay == AppSettings.triggerDelayRange.upperBound)
        #expect(settings.maxMenuDepth == 1)
    }

    @Test func ignoresStoredValuesOfTheWrongType() {
        let store = MemoryStore()
        store.values = [
            AppSettings.Key.triggerDelay: "fast",
            AppSettings.Key.maxMenuDepth: "deep",
            AppSettings.Key.showsDisabledItems: "yes",
            AppSettings.Key.showsSystemShortcuts: "no",
        ]

        #expect(AppSettings(store: store) == .defaults)
    }

    @Test func withCopiesChangeOneSetting() {
        let settings = AppSettings.defaults

        #expect(settings.with(triggerDelay: 0.3).triggerDelay == 0.3)
        #expect(settings.with(maxMenuDepth: 4).maxMenuDepth == 4)
        #expect(settings.with(showsDisabledItems: true).showsDisabledItems)
        #expect(!settings.with(showsSystemShortcuts: false).showsSystemShortcuts)
        #expect(settings.with(maxMenuDepth: 99).maxMenuDepth == AppSettings.maxMenuDepthRange.upperBound)
    }

    @Test func onlyReaderSettingsChangeMenuReads() {
        let settings = AppSettings.defaults

        #expect(!settings.changesMenuReads(comparedTo: settings))
        #expect(!settings.with(triggerDelay: 0.3).changesMenuReads(comparedTo: settings))
        #expect(settings.with(maxMenuDepth: 2).changesMenuReads(comparedTo: settings))
        #expect(settings.with(showsDisabledItems: true).changesMenuReads(comparedTo: settings))
        // System shortcuts are added when the overlay shows, not read from menus.
        #expect(!settings.with(showsSystemShortcuts: false).changesMenuReads(comparedTo: settings))
    }
}
