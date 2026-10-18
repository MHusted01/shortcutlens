/// Reads the keyboard shortcuts from an app's menu bar.
///
/// The tree is `AXMenuBar` -> `AXMenuBarItem` -> `AXMenu` -> `AXMenuItem`,
/// and an item with a submenu has an `AXMenu` child of its own. The reader
/// skips the Apple menu, follows submenus up to `maxDepth` levels, visits each
/// `AXMenu` at most once and keeps enabled items with a displayable key.
public struct MenuReader<Client: AXClient> {
    public typealias Element = Client.Element

    /// Deep enough for real apps; deeper trees are almost certainly broken.
    public static var defaultMaxDepth: Int {
        8
    }

    public let client: Client
    /// How many menu levels are read; the top-level menu is level 1.
    public let maxDepth: Int

    private static var menuRole: String {
        "AXMenu"
    }

    /// `maxDepth` values below 1 are raised to 1.
    public init(client: Client, maxDepth: Int = Self.defaultMaxDepth) {
        self.client = client
        self.maxDepth = max(maxDepth, 1)
    }

    /// The shortcuts of the process's menu bar, one group per top-level menu
    /// that has at least one. Empty when the menu bar cannot be read.
    public func read(processID: Int32) -> [MenuGroup<Element>] {
        guard let menuBar = client.menuBar(forProcess: processID) else {
            return []
        }
        var visited: Set<Element> = []
        // The first menu bar item is always the Apple menu.
        return client.children(of: menuBar).dropFirst().compactMap { barItem in
            group(for: barItem, visited: &visited)
        }
    }

    private func group(for barItem: Element, visited: inout Set<Element>) -> MenuGroup<Element>? {
        guard let title = client.attributes(of: barItem)?.title else {
            return nil
        }
        let items = submenus(of: barItem, visited: visited).flatMap { menu in
            entries(in: menu, path: [title], depth: 1, visited: &visited)
        }
        return items.isEmpty ? nil : MenuGroup(title: title, items: items)
    }

    /// The not yet visited `AXMenu` children of `element`.
    private func submenus(of element: Element, visited: Set<Element>) -> [Element] {
        client.children(of: element).filter { child in
            !visited.contains(child) && client.attributes(of: child)?.role == Self.menuRole
        }
    }

    private func entries(
        in menu: Element,
        path: [String],
        depth: Int,
        visited: inout Set<Element>
    ) -> [MenuEntry<Element>] {
        guard visited.insert(menu).inserted else {
            return []
        }
        return client.children(of: menu).flatMap { item -> [MenuEntry<Element>] in
            guard let attributes = client.attributes(of: item) else {
                return []
            }
            let itemPath = path + [attributes.title ?? ""]
            let own = entry(for: item, attributes: attributes, path: itemPath).map { [$0] } ?? []
            guard depth < maxDepth else {
                return own
            }
            let nested = submenus(of: item, visited: visited).flatMap { submenu in
                entries(in: submenu, path: itemPath, depth: depth + 1, visited: &visited)
            }
            return own + nested
        }
    }

    private func entry(for item: Element, attributes: MenuItemAttributes, path: [String]) -> MenuEntry<Element>? {
        guard attributes.isEnabled else {
            return nil
        }
        let shortcut = MenuShortcut(
            title: attributes.title ?? "",
            keyCharacter: attributes.keyCharacter,
            modifiers: ModifierMask(axValue: attributes.modifiers ?? 0),
            glyph: attributes.glyph,
            isEnabled: attributes.isEnabled,
            menuPath: path
        )
        guard ShortcutFormatter.keySymbol(for: shortcut) != nil else {
            return nil
        }
        return MenuEntry(shortcut: shortcut, element: item)
    }
}
