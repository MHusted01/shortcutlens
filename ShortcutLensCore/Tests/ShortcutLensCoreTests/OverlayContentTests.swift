import ShortcutLensCore
import Testing

struct OverlayContentTests {
    private func entry(_ title: String, key: String, modifiers: ModifierMask = [], element: Int) -> MenuEntry<Int> {
        MenuEntry(
            shortcut: MenuShortcut(title: title, keyCharacter: key, modifiers: modifiers, menuPath: ["File", title]),
            element: element
        )
    }

    @Test func buildsOneSectionPerGroupWithFormattedKeys() {
        let groups = [
            MenuGroup(title: "File", items: [entry("Save", key: "s", element: 1)]),
            MenuGroup(title: "Edit", items: [entry("Redo", key: "z", modifiers: .shift, element: 2)]),
        ]

        let content = OverlayContent(appName: "TextEdit", groups: groups)

        #expect(content.appName == "TextEdit")
        #expect(content.sections.map(\.title) == ["File", "Edit"])
        #expect(content.sections[0].rows == [OverlayRow(id: 0, title: "Save", keys: "⌘S", element: 1)])
        #expect(content.sections[1].rows == [OverlayRow(id: 0, title: "Redo", keys: "⇧⌘Z", element: 2)])
        #expect(!content.isEmpty)
    }

    @Test func rowsCarryWhetherTheItemIsEnabled() {
        let disabled = MenuEntry(
            shortcut: MenuShortcut(
                title: "Revert", keyCharacter: "r", modifiers: [], isEnabled: false, menuPath: ["File", "Revert"]
            ),
            element: 1
        )
        let group = MenuGroup(title: "File", items: [disabled, entry("Open", key: "o", element: 2)])

        let rows = OverlayContent(appName: "App", groups: [group]).sections[0].rows

        #expect(rows.map(\.isEnabled) == [false, true])
    }

    @Test func marksRowsWithAnAppShortcut() throws {
        let save = try #require(UserKeyEquivalent(title: "Save", keys: "@s"))
        let custom = UserKeyEquivalents(global: [], app: [save])
        let group = MenuGroup(title: "File", items: [
            entry("Save", key: "s", element: 1),
            entry("Open", key: "o", element: 2),
        ])

        let rows = OverlayContent(appName: "App", groups: [group], custom: custom).sections[0].rows

        #expect(rows.map(\.isCustom) == [true, false])
    }

    @Test func rowsAreNotMarkedWithoutAppShortcuts() {
        let group = MenuGroup(title: "File", items: [entry("Save", key: "s", element: 1)])
        let system = MenuShortcut(title: "Lock Screen", keyCharacter: "q", modifiers: .control)

        let content = OverlayContent(appName: "App", groups: [group])
            .appending(sectionTitle: "System", shortcuts: [system])

        #expect(content.sections.flatMap(\.rows).map(\.isCustom) == [false, false])
    }

    @Test func numbersRowsWithinEachSection() {
        let group = MenuGroup(title: "File", items: [
            entry("New", key: "n", element: 1),
            entry("Open", key: "o", element: 2),
        ])

        let content = OverlayContent(appName: "App", groups: [group])

        #expect(content.sections[0].rows.map(\.id) == [0, 1])
        #expect(content.sections.map(\.id) == [0])
    }

    /// AX cannot tell a hidden Option alternate ("Close All") from a visible
    /// item ("Hide Others"), so both are kept.
    @Test func keepsOptionVariants() {
        let group = MenuGroup(title: "File", items: [
            entry("Close", key: "w", element: 1),
            entry("Close All", key: "w", modifiers: .option, element: 2),
        ])

        let content = OverlayContent(appName: "App", groups: [group])

        #expect(content.sections[0].rows.map(\.title) == ["Close", "Close All"])
    }

    @Test func dropsRowsWithoutDisplayableKeyAndEmptySections() {
        let groups = [
            MenuGroup(title: "Broken", items: [entry("Odd", key: "\u{F8FF}", element: 1)]),
            MenuGroup(title: "File", items: [entry("Save", key: "s", element: 2)]),
        ]

        let content = OverlayContent(appName: "App", groups: groups)

        #expect(content.sections.map(\.title) == ["File"])
        #expect(content.sections.map(\.id) == [0])
    }

    @Test func isEmptyWithoutShortcuts() {
        let content = OverlayContent<Int>(appName: "Finder", groups: [])

        #expect(content.isEmpty)
        #expect(content.rowCount == 0)
    }

    @Test func countsRowsAcrossSections() {
        let groups = [
            MenuGroup(title: "File", items: [entry("New", key: "n", element: 1), entry("Open", key: "o", element: 2)]),
            MenuGroup(title: "Edit", items: [entry("Copy", key: "c", element: 3)]),
        ]

        #expect(OverlayContent(appName: "App", groups: groups).rowCount == 3)
    }

    @Test func appendsADisplayOnlySectionLast() {
        let groups = [MenuGroup(title: "File", items: [entry("Save", key: "s", element: 1)])]
        let spotlight = MenuShortcut(title: "Show Spotlight search", keyCharacter: " ", modifiers: [])

        let content = OverlayContent(appName: "App", groups: groups)
            .appending(sectionTitle: "System", shortcuts: [spotlight])

        #expect(content.sections.map(\.title) == ["File", "System"])
        #expect(content.sections.map(\.id) == [0, 1])
        #expect(content.sections[1].rows == [
            OverlayRow(id: 0, title: "Show Spotlight search", keys: "⌘Space", element: nil),
        ])
        #expect(!content.sections[1].rows[0].isRunnable)
        #expect(content.sections[0].rows[0].isRunnable)
    }

    /// An app without menu shortcuts shows the System section instead of the
    /// empty state.
    @Test func systemSectionMakesAnAppWithoutShortcutsNonEmpty() {
        let spotlight = MenuShortcut(title: "Show Spotlight search", keyCharacter: " ", modifiers: [])

        let content = OverlayContent<Int>(appName: "App", groups: [])
            .appending(sectionTitle: "System", shortcuts: [spotlight])

        #expect(!content.isEmpty)
        #expect(content.sections.map(\.id) == [0])
    }

    @Test func appendingNoDisplayableShortcutsAddsNoSection() {
        let noKey = MenuShortcut(title: "Show Launchpad", keyCharacter: nil, modifiers: .noCommand)

        let content = OverlayContent<Int>(appName: "App", groups: [])
            .appending(sectionTitle: "System", shortcuts: [noKey])

        #expect(content.isEmpty)
    }

    @Test func disabledRowsAreNotRunnable() {
        let row = OverlayRow(id: 0, title: "Revert", keys: "⌘R", isEnabled: false, element: 1)

        #expect(!row.isRunnable)
    }
}
