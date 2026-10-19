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

    @Test func opensOnGeneralWithoutAStoredTab() {
        #expect(SettingsTab(store: MemoryStore()) == .general)
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

    @Test func fallsBackToGeneralForAnUnknownName() {
        let store = MemoryStore()
        store.values[SettingsTab.storeKey] = "removed"

        #expect(SettingsTab(store: store) == .general)
    }

    @Test func fallsBackToGeneralForAValueOfTheWrongType() {
        let store = MemoryStore()
        store.values[SettingsTab.storeKey] = 2

        #expect(SettingsTab(store: store) == .general)
    }
}
