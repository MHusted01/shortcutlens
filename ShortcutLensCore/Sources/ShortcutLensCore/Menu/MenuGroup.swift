/// The shortcuts of one top-level menu, e.g. "File", including its submenus.
public struct MenuGroup<Element> {
    /// The top-level menu's title.
    public let title: String
    /// Shortcuts in menu order; submenu items follow the item that opens them.
    public let items: [MenuEntry<Element>]

    public init(title: String, items: [MenuEntry<Element>]) {
        self.title = title
        self.items = items
    }
}

/// A shortcut together with the element it was read from, so the menu item
/// can be pressed later.
public struct MenuEntry<Element> {
    public let shortcut: MenuShortcut
    public let element: Element

    public init(shortcut: MenuShortcut, element: Element) {
        self.shortcut = shortcut
        self.element = element
    }
}

extension MenuGroup: Equatable where Element: Equatable {}
extension MenuGroup: Hashable where Element: Hashable {}
extension MenuGroup: Sendable where Element: Sendable {}
extension MenuEntry: Equatable where Element: Equatable {}
extension MenuEntry: Hashable where Element: Hashable {}
extension MenuEntry: Sendable where Element: Sendable {}
