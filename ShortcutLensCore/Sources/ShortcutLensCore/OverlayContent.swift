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

    /// Rows whose item has an App Shortcut in `custom` are marked `isCustom`,
    /// and rows that share their keys with another row carry a `conflict`.
    public init(appName: String, groups: [MenuGroup<Element>], custom: UserKeyEquivalents = .empty) {
        let sections = groups
            .map { group in
                let entries = group.items.map { ($0.shortcut, $0.element) }
                return (title: group.title, rows: Self.rows(for: entries, custom: custom))
            }
            .filter { !$0.rows.isEmpty }
            .enumerated()
            .map { OverlaySection(id: $0.offset, title: $0.element.title, rows: $0.element.rows) }
        self = Self(appName: appName, sections: sections).markingConflicts()
    }

    /// Content from sections that are already built, e.g. a filtered copy.
    public init(appName: String, sections: [OverlaySection<Element>]) {
        self.appName = appName
        self.sections = sections
    }

    /// A copy with a section of display-only rows after the others, e.g. the
    /// system shortcuts. Shortcuts without a displayable key are left out, and
    /// no section is added when none is left. Conflicts are marked again over
    /// all sections, so app and system rows that share keys both say so.
    public func appending(sectionTitle: String, shortcuts: [MenuShortcut]) -> Self {
        appending(sections: [(title: sectionTitle, shortcuts: shortcuts)])
    }

    /// A copy with several display-only sections after the others, in order,
    /// e.g. a shortcut pack's. Works like `appending(sectionTitle:shortcuts:)`;
    /// conflicts are marked once over the result.
    public func appending(sections added: [(title: String, shortcuts: [MenuShortcut])]) -> Self {
        let built = added
            .map { (title: $0.title, rows: Self.rows(for: $0.shortcuts.map { ($0, nil) }, custom: .empty)) }
            .filter { !$0.rows.isEmpty }
        guard !built.isEmpty else {
            return self
        }
        let new = built.enumerated().map { offset, section in
            OverlaySection(id: sections.count + offset, title: section.title, rows: section.rows)
        }
        return Self(appName: appName, sections: sections + new).markingConflicts()
    }

    /// True when the app has no shortcut to show.
    public var isEmpty: Bool {
        sections.isEmpty
    }

    /// The number of rows over all sections.
    public var rowCount: Int {
        sections.reduce(0) { $0 + $1.rows.count }
    }

    private static func rows(
        for entries: [(shortcut: MenuShortcut, element: Element?)],
        custom: UserKeyEquivalents
    ) -> [OverlayRow<Element>] {
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
                    isCustom: custom.isCustom(item.entry.shortcut),
                    combo: KeyCombo(item.entry.shortcut),
                    menuPath: item.entry.shortcut.menuPath,
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
    /// True for the Favourites section, whose rows are copies of rows in
    /// other sections; see `pinning(_:)`.
    public let isPinned: Bool

    public init(id: Int, title: String, rows: [OverlayRow<Element>], isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.rows = rows
        self.isPinned = isPinned
    }

    /// The height of the rows in row heights; see `OverlayRow.lineCount`.
    public var lineCount: Int {
        rows.reduce(0) { $0 + $1.lineCount }
    }
}

/// One shortcut in the overlay, with the element to press for it. Rows without
/// an element, such as system shortcuts, are display-only.
public struct OverlayRow<Element>: Identifiable {
    /// Position within its section.
    public let id: Int
    public let title: String
    /// The formatted shortcut, e.g. `⇧⌘S`.
    public let keys: String
    /// False for a disabled menu item, shown dimmed and not runnable.
    public let isEnabled: Bool
    /// True when the user set this shortcut in App Shortcuts.
    public let isCustom: Bool
    /// True when the user pinned the item to the Favourites section.
    public let isFavourite: Bool
    /// The keys, for finding conflicts; nil when built without them.
    public let combo: KeyCombo?
    /// What else uses these keys, e.g. "Also used by System > Lock Screen".
    public let conflict: String?
    /// Titles from the top-level menu down to the item, for editing its
    /// shortcut; empty when built without them.
    public let menuPath: [String]
    /// The menu item to press; nil for a display-only row.
    public let element: Element?

    public init(
        id: Int,
        title: String,
        keys: String,
        isEnabled: Bool = true,
        isCustom: Bool = false,
        isFavourite: Bool = false,
        combo: KeyCombo? = nil,
        conflict: String? = nil,
        menuPath: [String] = [],
        element: Element?
    ) {
        self.id = id
        self.title = title
        self.keys = keys
        self.isEnabled = isEnabled
        self.isCustom = isCustom
        self.isFavourite = isFavourite
        self.combo = combo
        self.conflict = conflict
        self.menuPath = menuPath
        self.element = element
    }

    /// A copy with `conflict` replaced.
    public func with(conflict: String?) -> Self {
        copy(conflict: conflict)
    }

    /// A copy with `id` replaced.
    func with(id: Int) -> Self {
        copy(id: id)
    }

    /// A copy with `isFavourite` replaced.
    func with(isFavourite: Bool) -> Self {
        copy(isFavourite: isFavourite)
    }

    private func copy(id: Int? = nil, isFavourite: Bool? = nil, conflict: String?? = nil) -> Self {
        Self(
            id: id ?? self.id, title: title, keys: keys, isEnabled: isEnabled, isCustom: isCustom,
            isFavourite: isFavourite ?? self.isFavourite, combo: combo, conflict: conflict ?? self.conflict,
            menuPath: menuPath, element: element
        )
    }

    /// Whether the row can be pinned: only menu items have a path to find
    /// them by again.
    public var canBeFavourite: Bool {
        element != nil && !menuPath.isEmpty
    }

    /// Rows have a fixed height; a conflict adds a second line for its
    /// explanation.
    public var lineCount: Int {
        conflict == nil ? 1 : 2
    }

    /// Whether clicking or choosing the row can run something.
    public var isRunnable: Bool {
        isEnabled && element != nil
    }
}

extension OverlayContent: Sendable where Element: Sendable {}
extension OverlaySection: Equatable where Element: Equatable {}
extension OverlaySection: Sendable where Element: Sendable {}
extension OverlayRow: Equatable where Element: Equatable {}
extension OverlayRow: Sendable where Element: Sendable {}
