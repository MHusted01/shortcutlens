import AppKit

/// The fixture's menu bar. Change it together with the expected list in
/// IntegrationTests/MenuReaderIntegrationTests.swift.
///
/// Covers: plain and combined modifiers, a nested submenu two levels deep, a
/// disabled item, an item without a shortcut, and keys that AX reports as
/// glyphs (function key, arrow, delete, return, escape).
@MainActor
enum FixtureMenu {
    private struct Item {
        let title: String
        var key = ""
        var modifiers: NSEvent.ModifierFlags = [.command]
        var isEnabled = true
        var action: Selector?
        var submenu: [Item]?
    }

    static func makeMainMenu() -> NSMenu {
        let bar = NSMenu()
        // AppKit puts the Apple menu first; the first menu added here becomes the app menu.
        let quit = Item(title: "Quit MenuFixture", key: "q", action: #selector(NSApplication.terminate(_:)))
        add("MenuFixture", [quit], to: bar)
        add("File", fileItems, to: bar)
        add("Keys", keyItems, to: bar)
        add("Empty", [Item(title: "Nothing Here")], to: bar)
        return bar
    }

    private static let fileItems = [
        Item(title: "New", key: "n"),
        Item(title: "Save As…", key: "s", modifiers: [.command, .shift]),
        Item(title: "Revert", key: "r", isEnabled: false),
        Item(title: "Page Setup"),
        Item(title: "Export", submenu: [
            Item(title: "PDF", key: "p", modifiers: [.command, .option]),
            Item(title: "More", submenu: [
                Item(title: "Everything", key: "x", modifiers: [.control, .option, .shift, .command]),
            ]),
        ]),
    ]

    private static let keyItems = [
        Item(title: "Refresh", key: functionKey(NSF5FunctionKey), modifiers: []),
        Item(title: "Back", key: functionKey(NSLeftArrowFunctionKey)),
        Item(title: "Delete", key: "\u{8}"),
        Item(title: "Send", key: "\r", modifiers: [.shift]),
        Item(title: "Cancel", key: "\u{1B}", modifiers: []),
    ]

    /// AppKit's function-key constants are private-use code points.
    private static func functionKey(_ key: Int) -> String {
        UnicodeScalar(UInt16(key)).map { String(Character($0)) } ?? ""
    }

    private static func add(_ title: String, _ items: [Item], to bar: NSMenu) {
        let barItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        barItem.submenu = makeMenu(title, items)
        bar.addItem(barItem)
    }

    private static func makeMenu(_ title: String, _ items: [Item]) -> NSMenu {
        let menu = NSMenu(title: title)
        // Most items have no action; without this AppKit would disable them.
        menu.autoenablesItems = false
        for item in items {
            menu.addItem(makeItem(item))
        }
        return menu
    }

    private static func makeItem(_ item: Item) -> NSMenuItem {
        let menuItem = NSMenuItem(title: item.title, action: item.action, keyEquivalent: item.key)
        menuItem.keyEquivalentModifierMask = item.modifiers
        menuItem.isEnabled = item.isEnabled
        menuItem.submenu = item.submenu.map { makeMenu(item.title, $0) }
        return menuItem
    }
}
