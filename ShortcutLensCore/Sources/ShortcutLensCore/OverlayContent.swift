/// What the overlay displays for one app: its menus as sections of rows with
/// formatted key labels.
///
/// AppKit's hidden Option alternates (e.g. "Close All" ⌥⌘W next to "Close"
/// ⌘W) are kept: the Accessibility API reports them exactly like visible
/// items such as "Hide Others" ⌥⌘H, so they cannot be told apart, and every
/// listed shortcut works when pressed.
public struct OverlayContent<Element> {
    public let appName: String
    /// Non-empty sections in menu bar order.
    public let sections: [OverlaySection<Element>]

    public init(appName: String, groups: [MenuGroup<Element>]) {
        self.appName = appName
        sections = groups
            .map { (title: $0.title, rows: Self.rows(for: $0.items)) }
            .filter { !$0.rows.isEmpty }
            .enumerated()
            .map { OverlaySection(id: $0.offset, title: $0.element.title, rows: $0.element.rows) }
    }

    /// Content from sections that are already built, e.g. a filtered copy.
    public init(appName: String, sections: [OverlaySection<Element>]) {
        self.appName = appName
        self.sections = sections
    }

    /// True when the app has no shortcut to show.
    public var isEmpty: Bool {
        sections.isEmpty
    }

    /// The number of rows over all sections.
    public var rowCount: Int {
        sections.reduce(0) { $0 + $1.rows.count }
    }

    private static func rows(for entries: [MenuEntry<Element>]) -> [OverlayRow<Element>] {
        entries
            .compactMap { entry in
                ShortcutFormatter.string(for: entry.shortcut).map { (entry: entry, keys: $0) }
            }
            .enumerated()
            .map { index, item in
                OverlayRow(
                    id: index,
                    title: item.entry.shortcut.title,
                    keys: item.keys,
                    isEnabled: item.entry.shortcut.isEnabled,
                    element: item.entry.element
                )
            }
    }
}

/// One top-level menu in the overlay.
public struct OverlaySection<Element>: Identifiable {
    /// Position among the overlay's sections.
    public let id: Int
    public let title: String
    public let rows: [OverlayRow<Element>]

    public init(id: Int, title: String, rows: [OverlayRow<Element>]) {
        self.id = id
        self.title = title
        self.rows = rows
    }
}

/// One shortcut in the overlay, with the element to press for it.
public struct OverlayRow<Element>: Identifiable {
    /// Position within its section.
    public let id: Int
    public let title: String
    /// The formatted shortcut, e.g. `⇧⌘S`.
    public let keys: String
    /// False for a disabled menu item, shown dimmed and not runnable.
    public let isEnabled: Bool
    public let element: Element

    public init(id: Int, title: String, keys: String, isEnabled: Bool = true, element: Element) {
        self.id = id
        self.title = title
        self.keys = keys
        self.isEnabled = isEnabled
        self.element = element
    }
}

extension OverlayContent: Sendable where Element: Sendable {}
extension OverlaySection: Equatable where Element: Equatable {}
extension OverlaySection: Sendable where Element: Sendable {}
extension OverlayRow: Equatable where Element: Equatable {}
extension OverlayRow: Sendable where Element: Sendable {}
