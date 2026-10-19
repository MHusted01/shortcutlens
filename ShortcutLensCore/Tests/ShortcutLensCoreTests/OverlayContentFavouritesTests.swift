import ShortcutLensCore
import Testing

struct OverlayContentFavouritesTests {
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
                entry("Edit", "Paste", key: "v", element: 3),
            ]),
        ])
    }

    @Test func pinsFavouritesInTheirOrderAsAFirstSection() {
        let pinned = content.pinning([["Edit", "Paste"], ["File", "Save"]])

        #expect(pinned.sections.map(\.title) == [OverlayContent<Int>.favouritesTitle, "File", "Edit"])
        #expect(pinned.sections.map(\.id) == [0, 1, 2])
        #expect(pinned.sections.map(\.isPinned) == [true, false, false])
        let favourites = pinned.sections[0].rows
        #expect(favourites.map(\.title) == ["Paste", "Save"])
        #expect(favourites.map(\.id) == [0, 1])
        #expect(favourites.map(\.element) == [3, 1])
        #expect(favourites.map(\.isRunnable) == [true, true])
    }

    @Test func keepsOriginalsInPlaceAndStarsThem() {
        let pinned = content.pinning([["Edit", "Paste"]])

        #expect(pinned.sections[2].rows.map(\.title) == ["Copy", "Paste"])
        #expect(pinned.sections[2].rows.map(\.isFavourite) == [false, true])
        #expect(pinned.sections[1].rows.map(\.isFavourite) == [false])
        #expect(pinned.rowCount == 4)
    }

    @Test func hidesMissingFavouritesWithoutASection() {
        let pinned = content.pinning([["File", "Gone"]])

        #expect(pinned.sections.map(\.title) == ["File", "Edit"])
        #expect(pinned.sections.allSatisfy { !$0.isPinned })
    }

    @Test func starsOnlyTheRowItPinsWhenPathsRepeat() {
        let repeated = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "Edit", items: [
                entry("Edit", "Copy", key: "c", element: 1),
                entry("Edit", "Copy", key: "k", element: 2),
            ]),
        ])

        let pinned = repeated.pinning([["Edit", "Copy"]])

        #expect(pinned.sections[0].rows.map(\.element) == [1])
        #expect(pinned.sections[1].rows.map(\.isFavourite) == [true, false])
    }

    @Test func doesNotPinDisplayOnlyRows() {
        let withSystem = content.appending(sectionTitle: "System", shortcuts: [
            MenuShortcut(title: "Lock", keyCharacter: "q", modifiers: [.control], menuPath: ["System", "Lock"]),
        ])

        let pinned = withSystem.pinning([["System", "Lock"]])

        #expect(pinned.sections.map(\.title) == ["File", "Edit", "System"])
        #expect(pinned.sections[2].rows.map(\.isFavourite) == [false])
    }

    @Test func pinningAgainReplacesTheFavourites() {
        let repinned = content.pinning([["File", "Save"]]).pinning([["Edit", "Copy"]])

        #expect(repinned.sections.map(\.title) == [OverlayContent<Int>.favouritesTitle, "File", "Edit"])
        #expect(repinned.sections[0].rows.map(\.title) == ["Copy"])
        #expect(repinned.sections[1].rows.map(\.isFavourite) == [false])
        #expect(repinned.sections[2].rows.map(\.isFavourite) == [true, false])
    }

    @Test func pinningNothingRemovesTheSection() {
        let unpinned = content.pinning([["File", "Save"]]).pinning([])

        #expect(unpinned.sections.map(\.title) == ["File", "Edit"])
        #expect(unpinned.sections.map(\.id) == [0, 1])
        #expect(unpinned.sections.flatMap(\.rows).allSatisfy { !$0.isFavourite })
    }

    @Test func copiesAreNotConflictsButShowTheOriginalsConflict() {
        let clashing = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "File", items: [
                entry("File", "Save", key: "s", element: 1),
                entry("File", "Open", key: "o", element: 2),
            ]),
            MenuGroup(title: "Edit", items: [entry("Edit", "Select", key: "s", element: 3)]),
        ])

        let pinned = clashing.pinning([["File", "Open"], ["File", "Save"]])

        let favourites = pinned.sections[0].rows
        #expect(favourites[0].conflict == nil)
        #expect(favourites[1].conflict == pinned.sections[1].rows[0].conflict)
        #expect(pinned.sections[1].rows[0].conflict?.contains("Edit > Select") == true)
        #expect(pinned.sections[1].rows[0].conflict?.contains(OverlayContent<Int>.favouritesTitle) == false)
        #expect(pinned.sections[1].rows[1].conflict == nil)
    }

    @Test func appendingKeepsTheFavouritesSectionOutOfConflicts() {
        let pinned = content.pinning([["File", "Save"]])
            .appending(sectionTitle: "System", shortcuts: [
                MenuShortcut(title: "Lock", keyCharacter: "q", modifiers: [], menuPath: []),
            ])

        #expect(pinned.sections.map(\.isPinned) == [true, false, false, false])
        #expect(pinned.sections.flatMap(\.rows).allSatisfy { $0.conflict == nil })
    }

    @Test func filteringKeepsThePinnedFlag() {
        let filtered = ShortcutMatcher.filter(content.pinning([["File", "Save"]]), query: "save")

        #expect(filtered.sections.map(\.isPinned) == [true, false])
    }

    @Test func editingAFavouriteCopyDoesNotClashWithItsOriginal() {
        let pinned = content.pinning([["File", "Save"]])
        let keys = KeyCombo(key: "S", modifiers: [])

        #expect(pinned.clashes(with: keys, excludingSection: 0, row: 0).isEmpty)
        #expect(pinned.clashes(with: keys, excludingSection: 1, row: 0).isEmpty)
        #expect(pinned.clashes(with: KeyCombo(key: "C", modifiers: []), excludingSection: 0, row: 0) == [
            "Edit > Copy",
        ])
    }
}
