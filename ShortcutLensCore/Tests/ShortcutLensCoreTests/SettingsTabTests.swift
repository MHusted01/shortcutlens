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

struct SettingsTabTests {
    @Test func tabsFollowTheSpecOrder() {
        #expect(SettingsTab.allCases == [.general, .overlay, .packs, .advanced])
    }

    @Test func everyTabHasItsSymbol() {
        #expect(SettingsTab.allCases.map(\.symbolName) == [
            "gearshape", "rectangle.grid.2x2", "shippingbox", "slider.horizontal.3",
        ])
    }

    @Test func titlesAreEnglishByDefault() {
        #expect(SettingsTab.allCases.map(\.title) == ["General", "Overlay", "Packs", "Advanced"])
    }

    @Test func remembersTheLastTab() {
        let store = MemoryStore()

        SettingsTab.packs.save(to: store)

        #expect(SettingsTab(store: store) == .packs)
    }

    @Test func storesTheTabByName() {
        let store = MemoryStore()

        SettingsTab.advanced.save(to: store)

        #expect(store.values[SettingsTab.storeKey] as? String == "advanced")
    }

    /// Nothing stored, a tab that no longer exists, a value of the wrong type.
    @Test(arguments: [nil, "removed", 2] as [(any Sendable)?])
    func opensOnGeneralWithoutAKnownStoredTab(stored: (any Sendable)?) {
        let store = MemoryStore()
        store.values[SettingsTab.storeKey] = stored

        #expect(SettingsTab(store: store) == .general)
    }
}
