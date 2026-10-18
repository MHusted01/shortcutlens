/// The command palette's search state: the query, the rows it leaves visible
/// and which of them is selected.
///
/// The selection runs through the visible rows in display order (sections in
/// menu bar order, rows top to bottom) and wraps at both ends. Every change of
/// query or content selects the first visible row.
public struct PaletteState<Element> {
    /// A row by its section's and its own id.
    public struct RowID: Hashable, Sendable {
        public let section: Int
        public let row: Int

        public init(section: Int, row: Int) {
            self.section = section
            self.row = row
        }
    }

    /// What Escape does: clear a non-empty query, or close the palette.
    public enum EscapeOutcome {
        case cleared(PaletteState<Element>)
        case close
    }

    public let query: String
    /// The app's full content; nil while its menus are still being read.
    public let content: OverlayContent<Element>?
    /// `content` filtered by `query`.
    public let visible: OverlayContent<Element>?
    /// Visible rows in display order.
    private let order: [RowID]
    /// Position of the selected row in `order`; nil when no row is visible.
    private let index: Int?

    /// An empty query while the menus are still being read.
    public init() {
        self.init(query: "", content: nil)
    }

    private init(query: String, content: OverlayContent<Element>?) {
        let visible = content.map { ShortcutMatcher.filter($0, query: query) }
        let order = visible.map(Self.rowIDs) ?? []
        self.init(query: query, content: content, visible: visible, order: order, index: order.isEmpty ? nil : 0)
    }

    private init(
        query: String,
        content: OverlayContent<Element>?,
        visible: OverlayContent<Element>?,
        order: [RowID],
        index: Int?
    ) {
        self.query = query
        self.content = content
        self.visible = visible
        self.order = order
        self.index = index
    }

    /// The selected row; nil when no row is visible.
    public var selection: RowID? {
        index.map { order[$0] }
    }

    public var selectedRow: OverlayRow<Element>? {
        guard let selection else {
            return nil
        }
        return visible?.sections.first { $0.id == selection.section }?.rows.first { $0.id == selection.row }
    }

    /// The same query applied to new content, e.g. when the menu read finishes.
    public func with(content: OverlayContent<Element>) -> Self {
        Self(query: query, content: content)
    }

    public func with(query: String) -> Self {
        Self(query: query, content: content)
    }

    /// The selection moved `offset` rows down (negative: up), wrapping around.
    public func movingSelection(by offset: Int) -> Self {
        guard let index else {
            return self
        }
        let count = order.count
        let moved = ((index + offset) % count + count) % count
        return Self(query: query, content: content, visible: visible, order: order, index: moved)
    }

    public func escaped() -> EscapeOutcome {
        query.isEmpty ? .close : .cleared(with(query: ""))
    }

    private static func rowIDs(_ content: OverlayContent<Element>) -> [RowID] {
        content.sections.flatMap { section in
            section.rows.map { RowID(section: section.id, row: $0.id) }
        }
    }
}

extension PaletteState: Sendable where Element: Sendable {}
extension PaletteState.EscapeOutcome: Sendable where Element: Sendable {}
