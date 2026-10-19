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

struct FavouritesTests {
    private let save = ["File", "Save"]
    private let open = ["File", "Open…"]

    @Test func startsEmpty() {
        #expect(Favourites.empty.paths(for: "com.example.app").isEmpty)
        #expect(!Favourites.empty.contains(save, bundleID: "com.example.app"))
    }

    @Test func togglingAddsInOrderAndRemoves() {
        let added = Favourites.empty
            .toggling(save, bundleID: "app")
            .toggling(open, bundleID: "app")

        #expect(added.paths(for: "app") == [save, open])
        #expect(added.contains(open, bundleID: "app"))

        let removed = added.toggling(save, bundleID: "app")

        #expect(removed.paths(for: "app") == [open])
        #expect(!removed.contains(save, bundleID: "app"))
    }

    @Test func togglingDoesNotChangeTheOriginal() {
        let original = Favourites.empty.toggling(save, bundleID: "app")

        _ = original.toggling(open, bundleID: "app")

        #expect(original.paths(for: "app") == [save])
    }

    @Test func keepsAppsApart() {
        let favourites = Favourites.empty.toggling(save, bundleID: "one")

        #expect(favourites.paths(for: "two").isEmpty)
        #expect(!favourites.contains(save, bundleID: "two"))
    }

    @Test func ignoresAppsWithoutABundleIDAndEmptyPaths() {
        let favourites = Favourites.empty
            .toggling(save, bundleID: nil)
            .toggling([], bundleID: "app")

        #expect(favourites == .empty)
        #expect(favourites.paths(for: nil).isEmpty)
    }

    @Test func roundTripsThroughTheStore() {
        let store = MemoryStore()
        let favourites = Favourites.empty
            .toggling(save, bundleID: "one")
            .toggling(open, bundleID: "one")
            .toggling(open, bundleID: "two")

        favourites.save(to: store)

        #expect(Favourites(store: store) == favourites)
    }

    @Test func removingTheLastFavouriteDropsTheApp() {
        let store = MemoryStore()

        Favourites.empty.toggling(save, bundleID: "app").toggling(save, bundleID: "app").save(to: store)

        #expect(store.values[Favourites.storeKey] as? [String: [[String]]] == [:])
    }

    @Test func malformedStoreValuesLoadAsEmpty() {
        let store = MemoryStore()
        store.values[Favourites.storeKey] = "not a dictionary"

        #expect(Favourites(store: store) == .empty)
    }

    @Test func skipsMalformedAppsAndPathsButKeepsTheRest() {
        let store = MemoryStore()
        store.values[Favourites.storeKey] = [
            "good": [["File", "Save"], [], ["Edit", 3]] as [Any],
            "bad": "nope",
        ] as [String: Any]

        let favourites = Favourites(store: store)

        #expect(favourites.paths(for: "good") == [save])
        #expect(favourites.paths(for: "bad").isEmpty)
    }

    @Test func loadingDropsDuplicatePaths() {
        let store = MemoryStore()
        store.values[Favourites.storeKey] = ["app": [save, open, save]]

        #expect(Favourites(store: store).paths(for: "app") == [save, open])
    }
}
