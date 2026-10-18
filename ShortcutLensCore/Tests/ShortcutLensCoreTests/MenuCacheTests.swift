import ShortcutLensCore
import Testing

struct MenuCacheTests {
    @Test func startsEmpty() {
        let cache = MenuCache<Int, String>(capacity: 2)

        #expect(cache.value(for: 1) == nil)
        #expect(cache.isEmpty)
    }

    @Test func storesAndReplacesValues() {
        let cache = MenuCache<Int, String>(capacity: 2)
            .storing("old", for: 1)
            .storing("new", for: 1)

        #expect(cache.value(for: 1) == "new")
        #expect(cache.count == 1)
    }

    @Test func storingReturnsACopy() {
        let empty = MenuCache<Int, String>(capacity: 2)
        _ = empty.storing("a", for: 1)

        #expect(empty.value(for: 1) == nil)
    }

    @Test func dropsTheLeastRecentlyStoredBeyondCapacity() {
        let cache = MenuCache<Int, String>(capacity: 2)
            .storing("a", for: 1)
            .storing("b", for: 2)
            .storing("a2", for: 1)
            .storing("c", for: 3)

        #expect(cache.value(for: 2) == nil)
        #expect(cache.value(for: 1) == "a2")
        #expect(cache.value(for: 3) == "c")
        #expect(cache.count == 2)
    }

    @Test func capacityIsAtLeastOne() {
        let cache = MenuCache<Int, String>(capacity: 0)
            .storing("a", for: 1)

        #expect(cache.value(for: 1) == "a")
    }

    @Test func incompleteValueIsStoredWhenNothingIsCached() {
        let cache = MenuCache<Int, String>(capacity: 2)
            .storing("partial", for: 1, isComplete: false)

        #expect(cache.value(for: 1) == "partial")
    }

    @Test func incompleteValueDoesNotReplaceACachedOne() {
        let cache = MenuCache<Int, String>(capacity: 2)
            .storing("full", for: 1)
            .storing("partial", for: 1, isComplete: false)

        #expect(cache.value(for: 1) == "full")
    }

    @Test func removesAKey() {
        let cache = MenuCache<Int, String>(capacity: 2)
            .storing("a", for: 1)
            .storing("b", for: 2)
            .removing(1)

        #expect(cache.value(for: 1) == nil)
        #expect(cache.value(for: 2) == "b")
        #expect(cache.count == 1)
    }

    @Test func removingAMissingKeyChangesNothing() {
        let cache = MenuCache<Int, String>(capacity: 2).storing("a", for: 1)

        #expect(cache.removing(9).value(for: 1) == "a")
    }
}
