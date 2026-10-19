/// A menu item to be asked about, with the keys that answer it.
public struct PracticeCard: Equatable, Sendable {
    public let menuPath: [String]
    public let combo: KeyCombo
    /// The keys as the overlay shows them, e.g. `⇧⌘S`.
    public let keys: String

    public init(menuPath: [String], combo: KeyCombo, keys: String) {
        self.menuPath = menuPath
        self.combo = combo
        self.keys = keys
    }

    /// The question, e.g. `File › Save As…`.
    public var prompt: String {
        menuPath.joined(separator: " › ")
    }
}

/// Picks the practice questions for one app.
public enum PracticeDeck {
    /// Questions per session.
    public static let sessionLength = 10

    /// Return, keypad Enter and Escape without modifiers press the practice
    /// window's buttons, so they cannot be answered.
    private static let dialogKeys = [0x0B, 0x04, 0x1B].compactMap(MenuGlyph.symbol(for:)).map {
        KeyCombo(key: $0, modifiers: .noCommand)
    }

    /// One card per menu path for every menu item with keys, in menu order.
    /// Display-only rows (packs, System) and the Favourites copies are left
    /// out, and so are items on keys macOS uses itself, which never reach the
    /// practice window, and items on plain Return, Enter or Escape.
    public static func cards(
        from content: OverlayContent<some Any>,
        systemShortcuts: [MenuShortcut]
    ) -> [PracticeCard] {
        let reserved = Set(systemShortcuts.compactMap(KeyCombo.init) + dialogKeys)
        let cards = content.sections.filter { !$0.isPinned }.flatMap(\.rows).compactMap { row -> PracticeCard? in
            guard row.canBeFavourite, let combo = row.combo, !reserved.contains(combo) else {
                return nil
            }
            return PracticeCard(menuPath: row.menuPath, combo: combo, keys: row.keys)
        }
        let firstIndex = Dictionary(cards.enumerated().map { ($0.element.menuPath, $0.offset) }) { first, _ in first }
        return cards.enumerated().filter { firstIndex[$0.element.menuPath] == $0.offset }.map(\.element)
    }

    /// Up to `count` cards, weakest first: items answered wrong last time and
    /// items never asked, then each higher box in turn. Within a box,
    /// favourites come first; the rest is shuffled with `random`.
    public static func questions(
        from cards: [PracticeCard],
        progress: PracticeProgress,
        bundleID: String?,
        favourites: [[String]],
        count: Int = sessionLength,
        using random: inout some RandomNumberGenerator
    ) -> [PracticeCard] {
        let favourites = Set(favourites)
        let ranked = cards.shuffled(using: &random).enumerated().map { offset, card in
            let box = progress.box(for: card.menuPath, bundleID: bundleID) ?? PracticeProgress.boxes.lowerBound
            return (box: box, favourite: favourites.contains(card.menuPath) ? 0 : 1, offset: offset, card: card)
        }
        return ranked
            .sorted { ($0.box, $0.favourite, $0.offset) < ($1.box, $1.favourite, $1.offset) }
            .prefix(max(count, 0))
            .map(\.card)
    }
}
