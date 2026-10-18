import ShortcutLensCore
import Testing

struct MenuReaderTests {
    /// A tree whose first top-level menu is the Apple menu, as on macOS.
    private func makeClient() -> FakeAXClient {
        let client = FakeAXClient()
        let apple = client.addTopLevelMenu("Apple")
        client.addItem("Lock Screen", key: "Q", modifiers: 4, to: apple)
        return client
    }

    private func read(
        _ client: FakeAXClient,
        maxDepth: Int = MenuReader<FakeAXClient>.defaultMaxDepth
    ) -> [MenuGroup<Int>] {
        MenuReader(client: client, maxDepth: maxDepth).read(processID: FakeAXClient.pid)
    }

    @Test func readsShortcutsPerTopLevelMenu() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        let save = client.addItem("Save", key: "S", modifiers: 0, to: file)
        let edit = client.addTopLevelMenu("Edit")
        client.addItem("Copy", key: "C", to: edit)

        let groups = read(client)

        #expect(groups.map(\.title) == ["File", "Edit"])
        #expect(groups[0].items == [
            MenuEntry(
                shortcut: MenuShortcut(title: "Save", keyCharacter: "S", modifiers: [], menuPath: ["File", "Save"]),
                element: save
            ),
        ])
        #expect(groups[1].items.map(\.shortcut.title) == ["Copy"])
    }

    @Test func skipsTheAppleMenu() {
        let client = makeClient()

        #expect(read(client).isEmpty)
    }

    @Test func decodesModifiers() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        client.addItem("Save As…", key: "S", modifiers: 1, to: file)
        client.addItem("Bare", key: "B", modifiers: 8, to: file)

        let modifiers = read(client)[0].items.map(\.shortcut.modifiers)

        #expect(modifiers == [.shift, .noCommand])
    }

    @Test func flattensNestedSubmenusWithTheirPath() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        let export = client.addItem("Export", to: file)
        let exportMenu = client.addSubmenu(to: export)
        client.addItem("PDF", key: "P", modifiers: 2, to: exportMenu)
        let more = client.addItem("More", to: exportMenu)
        client.addItem("PNG", key: "G", to: client.addSubmenu(to: more))
        client.addItem("Close", key: "W", to: file)

        let paths = read(client)[0].items.map(\.shortcut.menuPath)

        #expect(paths == [["File", "Export", "PDF"], ["File", "Export", "More", "PNG"], ["File", "Close"]])
    }

    @Test func dropsDisabledItems() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        client.addItem("Revert", key: "R", isEnabled: false, to: file)
        client.addItem("Open", key: "O", to: file)

        #expect(read(client)[0].items.map(\.shortcut.title) == ["Open"])
    }

    @Test func dropsItemsWithoutShortcut() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        client.addItem("Page Setup", to: file)
        client.addItem("Empty Key", key: "", modifiers: 0, to: file)
        client.addItem("Unknown Glyph Only", glyph: 0, to: file)
        client.addItem("Print", key: "P", to: file)

        #expect(read(client)[0].items.map(\.shortcut.title) == ["Print"])
    }

    @Test func keepsGlyphOnlyItems() {
        let client = makeClient()
        let view = client.addTopLevelMenu("View")
        client.addItem("Refresh", modifiers: 8, glyph: 0x73, to: view)

        let shortcut = read(client)[0].items[0].shortcut

        #expect(shortcut.keyCharacter == nil)
        #expect(shortcut.glyph == 0x73)
        #expect(shortcut.modifiers == .noCommand)
    }

    @Test func dropsMenusWithoutShortcuts() {
        let client = makeClient()
        let window = client.addTopLevelMenu("Window")
        client.addItem("Zoom", to: window)
        let help = client.addTopLevelMenu("Help")
        client.addItem("Help", key: "?", modifiers: 1, to: help)

        #expect(read(client).map(\.title) == ["Help"])
    }

    @Test func stopsAtTheDepthLimit() {
        let client = makeClient()
        var menu = client.addTopLevelMenu("Deep")
        for level in 1 ... 4 {
            client.addItem("Level \(level)", key: "\(level)", to: menu)
            menu = client.addSubmenu(to: client.addItem("Next", to: menu))
        }

        let titles = read(client, maxDepth: 2)[0].items.map(\.shortcut.title)

        #expect(titles == ["Level 1", "Level 2"])
    }

    @Test func survivesCycles() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        client.addItem("Open", key: "O", to: file)
        let loopMenu = client.addSubmenu(to: client.addItem("Loop", to: file))
        client.addItem("Inner", key: "I", to: loopMenu)
        // "Back" opens the File menu again: without a guard this repeats until the depth limit.
        client.link(file, to: client.addItem("Back", to: loopMenu))

        let titles = read(client)[0].items.map(\.shortcut.title)

        #expect(titles == ["Open", "Inner"])
    }

    @Test func ignoresUnreadableElements() {
        let client = makeClient()
        client.addUnreadable(to: FakeAXClient.menuBar)
        let file = client.addTopLevelMenu("File")
        client.addUnreadable(to: file)
        client.addItem("Open", key: "O", to: file)

        #expect(read(client).map(\.title) == ["File"])
    }

    @Test func ignoresChildrenThatAreNotMenus() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        let item = client.addItem("Recent", to: file)
        client.addItem("Hidden", key: "H", to: item)

        #expect(read(client).isEmpty)
    }

    @Test func returnsNothingWithoutMenuBar() {
        let reader = MenuReader(client: makeClient())

        #expect(reader.read(processID: 7).isEmpty)
    }

    @Test func clampsDepthToAtLeastOne() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        client.addItem("Open", key: "O", to: file)

        #expect(MenuReader(client: client, maxDepth: 0).maxDepth == 1)
        #expect(read(client, maxDepth: -3).map(\.title) == ["File"])
    }

    @Test func readsAttributesOncePerElement() {
        let client = makeClient()
        let file = client.addTopLevelMenu("File")
        client.addItem("Open", key: "O", to: file)
        client.addItem("Save", key: "S", to: file)

        _ = read(client)

        // The Apple menu is skipped unread; then File's bar item, its AXMenu and two items.
        #expect(client.attributeReads == 4)
    }
}
