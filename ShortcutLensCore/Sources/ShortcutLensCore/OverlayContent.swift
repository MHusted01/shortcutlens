/// What the overlay displays for one app: its menus as sections of rows with
/// formatted key labels. Option alternates are hidden (see `OptionAlternates`).
public struct OverlayContent<Element> {
    public let appName: String
    /// Non-empty sections in menu bar order.
    public let sections: [OverlaySection<Element>]

    public init(appName: String, groups: [MenuGroup<Element>]) {
        self.appName = appName
        sections = OptionAlternates.removed(from: groups)
            .map { (title: $0.title, rows: Self.rows(for: $0.items)) }
            .filter { !$0.rows.isEmpty }
            .enumerated()
            .map { OverlaySection(id: $0.offset, title: $0.element.title, rows: $0.element.rows) }
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
                OverlayRow(id: index, title: item.entry.shortcut.title, keys: item.keys, element: item.entry.element)
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
    public let element: Element

    public init(id: Int, title: String, keys: String, element: Element) {
        self.id = id
        self.title = title
        self.keys = keys
        self.element = element
    }
}

extension OverlaySection: Equatable where Element: Equatable {}
extension OverlayRow: Equatable where Element: Equatable {}
