import ShortcutLensCore
import Testing

struct OverlayContentEditTests {
    private func entry(_ menu: String, _ title: String, key: String, modifiers: ModifierMask = []) -> MenuEntry<Int> {
        MenuEntry(
            shortcut: MenuShortcut(title: title, keyCharacter: key, modifiers: modifiers, menuPath: [menu, title]),
            element: 0
        )
    }

    private var content: OverlayContent<Int> {
        let groups = [
            MenuGroup(title: "File", items: [entry("File", "Save", key: "s"), entry("File", "Close", key: "w")]),
            MenuGroup(title: "Edit", items: [entry("Edit", "Find", key: "f")]),
        ]
        let lock = MenuShortcut(title: "Lock Screen", keyCharacter: "q", modifiers: [.control])
        return OverlayContent(appName: "App", groups: groups).appending(sectionTitle: "System", shortcuts: [lock])
    }

    @Test func rowsCarryTheirMenuPath() {
        #expect(content.sections[0].rows.map(\.menuPath) == [["File", "Save"], ["File", "Close"]])
    }

    @Test func findsAppAndSystemRowsOnTheProposedKeys() {
        let find = KeyCombo(key: "F", modifiers: [])
        let lock = KeyCombo(key: "Q", modifiers: .control)

        #expect(content.clashes(with: find, excludingSection: 0, row: 0) == ["Edit > Find"])
        #expect(content.clashes(with: lock, excludingSection: 0, row: 0) == ["System > Lock Screen"])
    }

    @Test func leavesOutTheEditedRow() {
        let save = KeyCombo(key: "S", modifiers: [])

        #expect(content.clashes(with: save, excludingSection: 0, row: 0).isEmpty)
        #expect(content.clashes(with: save, excludingSection: 1, row: 0) == ["File > Save"])
    }

    @Test func freeKeysClashWithNothing() {
        #expect(content.clashes(with: KeyCombo(key: "K", modifiers: .option), excludingSection: 0, row: 1).isEmpty)
    }
}
