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
    /// Settings where every value differs from the default.
    private func changed(
        triggerDelay: Double = 0.4, maxMenuDepth: Int = 2, showsDisabledItems: Bool = true,
        showsSystemShortcuts: Bool = false, paletteTrigger: PaletteTrigger = .off
    ) -> AppSettings {
        AppSettings(
            triggerDelay: triggerDelay, maxMenuDepth: maxMenuDepth, showsDisabledItems: showsDisabledItems,
            showsSystemShortcuts: showsSystemShortcuts, paletteTrigger: paletteTrigger
        )
    }

    @Test func defaultsMatchTheBuiltInBehaviour() {
        let settings = AppSettings.defaults

        #expect(settings.triggerDelay == TriggerStateMachine.defaultDelay)
        #expect(settings.maxMenuDepth == MenuReader<FakeAXClient>.defaultMaxDepth)
        #expect(!settings.showsDisabledItems)
        #expect(settings.showsSystemShortcuts)
        #expect(settings.paletteTrigger == .command)
    }

    @Test func clampsTriggerDelayToItsRange() {
        #expect(AppSettings(triggerDelay: 0).triggerDelay == AppSettings.triggerDelayRange.lowerBound)
        #expect(AppSettings(triggerDelay: 9).triggerDelay == AppSettings.triggerDelayRange.upperBound)
        #expect(AppSettings(triggerDelay: 0.5).triggerDelay == 0.5)
    }

    /// Rounded values equal their literals: 6 × 0.05 is 0.30000000000000004.
    @Test(arguments: [(0.52, 0.5), (0.53, 0.55), (0.3, 0.3)])
    func roundsTriggerDelayToItsStep(delay: Double, expected: Double) {
        #expect(AppSettings(triggerDelay: delay).triggerDelay == expected)
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

    /// `UserDefaults` hands numbers back as `NSNumber`; they must still read
    /// as `Double`, `Int` and `Bool`.
    @Test func roundTripsThroughUserDefaults() throws {
        let suite = "dev.shortcutlens.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(
            triggerDelay: 0.65, maxMenuDepth: 3, showsDisabledItems: true, showsSystemShortcuts: false,
            paletteTrigger: .off
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
            AppSettings.Key.paletteTrigger: 2,
        ]

        #expect(AppSettings(store: store) == .defaults)
    }

    /// A value from a newer version, or a typo in a hand-edited store.
    @Test func unknownPaletteTriggerFallsBackToCommand() {
        let store = MemoryStore()
        store.values = [AppSettings.Key.paletteTrigger: "fn"]

        #expect(AppSettings(store: store).paletteTrigger == .command)
    }

    @Test func storesPaletteTriggerAsItsName() {
        let store = MemoryStore()

        AppSettings.defaults.with(paletteTrigger: .option).save(to: store)

        #expect(store.values[AppSettings.Key.paletteTrigger] as? String == "option")
    }

    @Test func withCopiesChangeOnlyTheirSetting() {
        let settings = changed()

        #expect(settings.with(triggerDelay: 0.3) == changed(triggerDelay: 0.3))
        #expect(settings.with(maxMenuDepth: 4) == changed(maxMenuDepth: 4))
        #expect(settings.with(showsDisabledItems: false) == changed(showsDisabledItems: false))
        #expect(settings.with(showsSystemShortcuts: true) == changed(showsSystemShortcuts: true))
        #expect(settings.with(paletteTrigger: .option) == changed(paletteTrigger: .option))
    }

    @Test func onlyReaderSettingsChangeMenuReads() {
        let settings = AppSettings.defaults

        #expect(!settings.changesMenuReads(comparedTo: settings))
        #expect(!settings.with(triggerDelay: 0.3).changesMenuReads(comparedTo: settings))
        #expect(!settings.with(paletteTrigger: .off).changesMenuReads(comparedTo: settings))
        #expect(settings.with(maxMenuDepth: 2).changesMenuReads(comparedTo: settings))
        #expect(settings.with(showsDisabledItems: true).changesMenuReads(comparedTo: settings))
        // System shortcuts are added when the overlay shows, not read from menus.
        #expect(!settings.with(showsSystemShortcuts: false).changesMenuReads(comparedTo: settings))
    }

    @Test func readerChangesAndTurningSystemShortcutsOnRestartReads() {
        let off = AppSettings.defaults.with(showsSystemShortcuts: false)

        #expect(!off.restartsReads(comparedTo: off))
        #expect(off.with(maxMenuDepth: 2).restartsReads(comparedTo: off))
        // A running read made with the toggle off has no system shortcuts.
        #expect(AppSettings.defaults.restartsReads(comparedTo: off))
        #expect(!off.restartsReads(comparedTo: .defaults))
    }
}
