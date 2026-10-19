import ShortcutLensCore
import Testing

struct OverlayContentPathsTests {
    private func entry(_ path: [String], key: String, element: Int) -> MenuEntry<Int> {
        MenuEntry(
            shortcut: MenuShortcut(title: path.last ?? "", keyCharacter: key, modifiers: [], menuPath: path),
            element: element
        )
    }

    private func titles(_ section: OverlaySection<Int>) -> [String] {
        section.rows.map(\.displayTitle)
    }

    /// Edit with two "Find Next" items in different submenus.
    private var findNext: OverlayContent<Int> {
        OverlayContent(appName: "App", groups: [
            MenuGroup(title: "Edit", items: [
                entry(["Edit", "Find", "Find Next"], key: "g", element: 1),
                entry(["Edit", "Spelling", "Find Next"], key: ";", element: 2),
                entry(["Edit", "Copy"], key: "c", element: 3),
            ]),
        ])
    }

    @Test func showsThePathBelowTheMenuWhenTitlesRepeatInASection() {
        #expect(titles(findNext.sections[0]) == ["Find > Find Next", "Spelling > Find Next", "Copy"])
        #expect(findNext.sections[0].rows.map(\.title) == ["Find Next", "Find Next", "Copy"])
    }

    @Test func keepsTheTitleOfATopLevelItemThatRepeatsASubmenuItem() {
        let content = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "Edit", items: [
                entry(["Edit", "Find Next"], key: "g", element: 1),
                entry(["Edit", "Find", "Find Next"], key: "f", element: 2),
            ]),
        ])

        #expect(titles(content.sections[0]) == ["Find Next", "Find > Find Next"])
    }

    @Test func titlesInDifferentSectionsStayPlain() {
        let content = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "File", items: [entry(["File", "Close"], key: "w", element: 1)]),
            MenuGroup(title: "Window", items: [entry(["Window", "Close"], key: "x", element: 2)]),
        ])

        #expect(content.sections.map(titles) == [["Close"], ["Close"]])
    }

    @Test func identicalPathsKeepTheirSharedLabel() {
        let content = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "View", items: [
                entry(["View", "Zoom", "Zoom In"], key: "+", element: 1),
                entry(["View", "Zoom", "Zoom In"], key: "=", element: 2),
            ]),
        ])

        #expect(titles(content.sections[0]) == ["Zoom > Zoom In", "Zoom > Zoom In"])
    }

    @Test func rowsWithoutAPathKeepTheirTitle() {
        let shortcut = MenuShortcut(title: "Lock", keyCharacter: "q", modifiers: [])
        let content = OverlayContent<Int>(appName: "App", groups: [])
            .appending(sectionTitle: "System", shortcuts: [shortcut, shortcut])

        #expect(titles(content.sections[0]) == ["Lock", "Lock"])
    }

    @Test func favouritesShowTheFullPathWhenTitlesRepeat() {
        let content = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "File", items: [entry(["File", "Close"], key: "w", element: 1)]),
            MenuGroup(title: "Window", items: [
                entry(["Window", "Close"], key: "x", element: 2),
                entry(["Window", "Minimize"], key: "m", element: 3),
            ]),
        ])

        let pinned = content.pinning([["File", "Close"], ["Window", "Close"], ["Window", "Minimize"]])

        #expect(titles(pinned.sections[0]) == ["File > Close", "Window > Close", "Minimize"])
        #expect(pinned.sections.dropFirst().map(titles) == [["Close"], ["Close", "Minimize"]])
    }

    @Test func aFavouriteWithAUniqueTitleDropsItsPath() {
        let pinned = findNext.pinning([["Edit", "Find", "Find Next"]])

        #expect(titles(pinned.sections[0]) == ["Find Next"])
        #expect(titles(pinned.sections[1]) == ["Find > Find Next", "Spelling > Find Next", "Copy"])
    }

    @Test func conflictsNameRowsByTheirPath() {
        let content = OverlayContent(appName: "App", groups: [
            MenuGroup(title: "Edit", items: [
                entry(["Edit", "Find", "Find Next"], key: "g", element: 1),
                entry(["Edit", "Spelling", "Find Next"], key: "g", element: 2),
            ]),
        ])

        #expect(content.sections[0].rows.map(\.conflict) == [
            "Also used by Edit > Spelling > Find Next",
            "Also used by Edit > Find > Find Next",
        ])
    }

    @Test func editClashesNameRowsByTheirPath() throws {
        let combo = try #require(KeyCombo(MenuShortcut(title: "", keyCharacter: ";", modifiers: [])))

        #expect(findNext.clashes(with: combo, excludingSection: 0, row: 0) == ["Edit > Spelling > Find Next"])
    }

    @Test func searchMatchesThePlainTitleAndKeepsLabels() {
        let filtered = ShortcutMatcher.filter(findNext, query: "find next")

        #expect(titles(filtered.sections[0]) == ["Find > Find Next", "Spelling > Find Next"])
    }
}
