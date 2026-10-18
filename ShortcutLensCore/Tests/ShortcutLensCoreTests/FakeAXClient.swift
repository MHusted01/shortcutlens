import ShortcutLensCore

/// An in-memory accessibility tree for `MenuReader` and `MenuItemRunner`
/// tests. Elements are integer ids; `menuBar` is element 0 and every other
/// node is built with the helpers below.
final class FakeAXClient: AXActionClient {
    struct Node {
        let attributes: MenuItemAttributes?
        var children: [Int]
    }

    static let menuBar = 0
    static let pid: Int32 = 42

    private(set) var nodes: [Int: Node] = [menuBar: Node(attributes: nil, children: [])]
    private(set) var attributeReads = 0
    /// Elements pressed, in order.
    private(set) var presses: [Int] = []
    /// The error `press` returns per element; absent elements press fine.
    var pressErrors: [Int: AXPressError] = [:]

    func menuBar(forProcess pid: Int32) -> Int? {
        pid == Self.pid ? Self.menuBar : nil
    }

    func children(of element: Int) -> [Int] {
        nodes[element]?.children ?? []
    }

    func attributes(of element: Int) -> MenuItemAttributes? {
        attributeReads += 1
        return nodes[element]?.attributes
    }

    func press(_ element: Int) -> AXPressError? {
        presses.append(element)
        return pressErrors[element]
    }

    // MARK: - Building the tree

    /// Adds a top-level menu (an `AXMenuBarItem` with one `AXMenu` child) and
    /// returns the id of that `AXMenu`.
    @discardableResult
    func addTopLevelMenu(_ title: String) -> Int {
        let barItem = add(MenuItemAttributes(title: title, role: "AXMenuBarItem"), to: Self.menuBar)
        return add(MenuItemAttributes(title: title, role: "AXMenu"), to: barItem)
    }

    /// Adds a menu item to `menu` and returns its id.
    @discardableResult
    func addItem(
        _ title: String,
        key: String? = nil,
        modifiers: Int? = nil,
        glyph: Int? = nil,
        isEnabled: Bool = true,
        to menu: Int
    ) -> Int {
        let attributes = MenuItemAttributes(
            title: title,
            isEnabled: isEnabled,
            role: "AXMenuItem",
            keyCharacter: key,
            modifiers: modifiers,
            glyph: glyph
        )
        return add(attributes, to: menu)
    }

    /// Adds a submenu (an `AXMenu`) below `item` and returns its id.
    func addSubmenu(to item: Int) -> Int {
        add(MenuItemAttributes(title: nil, role: "AXMenu"), to: item)
    }

    /// Adds an existing element as an extra child, which can create a cycle.
    func link(_ child: Int, to parent: Int) {
        nodes[parent]?.children.append(child)
    }

    /// Adds a child whose attributes cannot be read.
    func addUnreadable(to parent: Int) {
        add(nil, to: parent)
    }

    /// Replaces the attributes of `element`, as when an app updates a menu
    /// item between the read and the click.
    func setAttributes(_ attributes: MenuItemAttributes?, of element: Int) {
        nodes[element] = Node(attributes: attributes, children: nodes[element]?.children ?? [])
    }

    @discardableResult
    private func add(_ attributes: MenuItemAttributes?, to parent: Int) -> Int {
        let id = nodes.count
        nodes[id] = Node(attributes: attributes, children: [])
        nodes[parent]?.children.append(id)
        return id
    }
}
