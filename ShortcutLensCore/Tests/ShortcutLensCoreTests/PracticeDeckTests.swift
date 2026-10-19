import ShortcutLensCore
import Testing

/// A seeded generator (SplitMix64), so shuffles repeat.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

struct PracticeDeckTests {
    private func entry(_ menu: String, _ title: String, key: String, element: Int) -> MenuEntry<Int> {
        MenuEntry(
            shortcut: MenuShortcut(title: title, keyCharacter: key, modifiers: [], menuPath: [menu, title]),
            element: element
        )
    }

    private var content: OverlayContent<Int> {
        OverlayContent(appName: "App", groups: [
            MenuGroup(title: "File", items: [entry("File", "Save", key: "s", element: 1)]),
            MenuGroup(title: "Edit", items: [
                entry("Edit", "Copy", key: "c", element: 2),
                entry("Edit", "Find", key: " ", element: 3),
            ]),
        ])
    }

    private func card(_ path: [String], _ key: String = "S") -> PracticeCard {
        PracticeCard(menuPath: path, combo: KeyCombo(key: key, modifiers: []), keys: "⌘" + key)
    }

    private func paths(_ cards: [PracticeCard]) -> [[String]] {
        cards.map(\.menuPath)
    }

    // MARK: - Cards

    @Test func makesACardForEachMenuShortcut() {
        let cards = PracticeDeck.cards(from: content, systemShortcuts: [])

        #expect(paths(cards) == [["File", "Save"], ["Edit", "Copy"], ["Edit", "Find"]])
        #expect(cards.map(\.keys) == ["⌘S", "⌘C", "⌘Space"])
        #expect(cards.map(\.prompt) == ["File › Save", "Edit › Copy", "Edit › Find"])
    }

    @Test func leavesOutSystemShortcuts() {
        let spotlight = MenuShortcut(title: "Spotlight", keyCharacter: " ", modifiers: [], glyph: 0x09)

        let cards = PracticeDeck.cards(from: content, systemShortcuts: [spotlight])

        #expect(paths(cards) == [["File", "Save"], ["Edit", "Copy"]])
    }

    @Test func leavesOutDisplayOnlyRows() {
        let pack = MenuShortcut(title: "Pack", keyCharacter: "p", modifiers: [], menuPath: ["Pack", "Pack"])
        let extended = content.appending(sectionTitle: "Pack", shortcuts: [pack])

        #expect(paths(PracticeDeck.cards(from: extended, systemShortcuts: [])).count == 3)
    }

    @Test func asksAPinnedItemOnce() {
        let pinned = content.pinning([["Edit", "Copy"]])

        let cards = PracticeDeck.cards(from: pinned, systemShortcuts: [])

        #expect(paths(cards) == [["File", "Save"], ["Edit", "Copy"], ["Edit", "Find"]])
    }

    @Test func asksOnePathOnce() {
        let twice = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "File", items: [
                entry("File", "Save", key: "s", element: 1),
                entry("File", "Save", key: "d", element: 2),
            ]),
        ])

        let cards = PracticeDeck.cards(from: twice, systemShortcuts: [])

        #expect(cards.map(\.keys) == ["⌘S"])
    }

    // MARK: - Questions

    @Test func asksWeakAndNewItemsBeforeKnownOnes() {
        let known = ["File", "Known"]
        let learning = ["File", "Learning"]
        let wrong = ["File", "Wrong"]
        let progress = PracticeProgress.empty
            .recording(correct: true, for: known, bundleID: "app")
            .recording(correct: true, for: known, bundleID: "app")
            .recording(correct: true, for: learning, bundleID: "app")
            .recording(correct: false, for: wrong, bundleID: "app")
        var random = SeededGenerator(seed: 1)

        let questions = PracticeDeck.questions(
            from: [card(known), card(learning), card(wrong)],
            progress: progress, bundleID: "app", favourites: [], using: &random
        )

        #expect(paths(questions) == [wrong, learning, known])
    }

    @Test func newItemsShareTheFirstLevel() {
        let new = ["File", "New"]
        let wrong = ["File", "Wrong"]
        let progress = PracticeProgress.empty.recording(correct: false, for: wrong, bundleID: "app")
        let orders = Set((0 ..< 20).map { seed in
            var random = SeededGenerator(seed: UInt64(seed))
            return paths(PracticeDeck.questions(
                from: [card(new), card(wrong)], progress: progress, bundleID: "app", favourites: [], using: &random
            ))
        })

        #expect(orders == [[new, wrong], [wrong, new]])
    }

    @Test func asksFavouritesFirstWithinALevel() {
        let favourite = ["Edit", "Copy"]
        let known = ["File", "Known"]
        let progress = PracticeProgress.empty.recording(correct: true, for: known, bundleID: "app")
        var random = SeededGenerator(seed: 3)

        let questions = PracticeDeck.questions(
            from: [card(["File", "Save"]), card(known), card(["Edit", "Paste"]), card(favourite)],
            progress: progress, bundleID: "app", favourites: [favourite], using: &random
        )

        #expect(questions.first?.menuPath == favourite)
        #expect(questions.last?.menuPath == known)
    }

    @Test func asksAtMostTheSessionLength() {
        let cards = (0 ..< 15).map { card(["File", "Item \($0)"]) }
        var random = SeededGenerator(seed: 4)

        let questions = PracticeDeck.questions(
            from: cards, progress: .empty, bundleID: "app", favourites: [], using: &random
        )
        let short = PracticeDeck.questions(
            from: Array(cards.prefix(3)), progress: .empty, bundleID: "app", favourites: [], count: 5, using: &random
        )

        #expect(questions.count == PracticeDeck.sessionLength)
        #expect(Set(paths(questions)).count == PracticeDeck.sessionLength)
        #expect(short.count == 3)
    }

    @Test func theSameSeedAsksTheSameOrder() {
        let cards = (0 ..< 8).map { card(["File", "Item \($0)"]) }
        var first = SeededGenerator(seed: 7)
        var second = SeededGenerator(seed: 7)

        let one = PracticeDeck.questions(from: cards, progress: .empty, bundleID: "app", favourites: [], using: &first)
        let two = PracticeDeck.questions(from: cards, progress: .empty, bundleID: "app", favourites: [], using: &second)

        #expect(paths(one) == paths(two))
    }
}
