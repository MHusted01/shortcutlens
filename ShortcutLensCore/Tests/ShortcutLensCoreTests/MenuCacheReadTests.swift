import ShortcutLensCore
import Testing

struct MenuCacheReadTests {
    private typealias Cache = MenuCache<Int, OverlayContent<Int>>

    private func content(_ titles: String...) -> OverlayContent<Int> {
        let items = titles.enumerated().map { index, title in
            MenuEntry(
                shortcut: MenuShortcut(title: title, keyCharacter: "K", modifiers: [], menuPath: ["File", title]),
                element: index
            )
        }
        return OverlayContent(appName: "App", groups: [MenuGroup(title: "File", items: items)])
    }

    private func titles(_ content: OverlayContent<Int>?) -> [String]? {
        content?.sections.flatMap(\.rows).map(\.title)
    }

    @Test func storesACompleteRead() {
        let cache = Cache(capacity: 2).storing(read: content("Save"), for: 1, budgetSpent: false)

        #expect(titles(cache.value(for: 1)) == ["Save"])
    }

    @Test func completeReadReplacesCachedContent() {
        let cache = Cache(capacity: 2)
            .storing(read: content("Save", "Open"), for: 1, budgetSpent: false)
            .storing(read: content("Save", "Export"), for: 1, budgetSpent: false)

        #expect(titles(cache.value(for: 1)) == ["Save", "Export"])
    }

    @Test func doesNotCacheAnEmptyRead() {
        let empty = OverlayContent<Int>(appName: "App", groups: [])
        let cache = Cache(capacity: 2).storing(read: empty, for: 1, budgetSpent: false)

        #expect(cache.value(for: 1) == nil)
    }

    @Test func emptyReadKeepsCachedContent() {
        let empty = OverlayContent<Int>(appName: "App", groups: [])
        let cache = Cache(capacity: 2)
            .storing(read: content("Save"), for: 1, budgetSpent: false)
            .storing(read: empty, for: 1, budgetSpent: false)

        #expect(titles(cache.value(for: 1)) == ["Save"])
    }

    @Test func partialReadFillsAnEmptySlot() {
        let cache = Cache(capacity: 2).storing(read: content("Save"), for: 1, budgetSpent: true)

        #expect(titles(cache.value(for: 1)) == ["Save"])
    }

    @Test func partialReadKeepsCachedContent() {
        let cache = Cache(capacity: 2)
            .storing(read: content("Save", "Open"), for: 1, budgetSpent: false)
            .storing(read: content("Save"), for: 1, budgetSpent: true)

        #expect(titles(cache.value(for: 1)) == ["Save", "Open"])
    }
}
