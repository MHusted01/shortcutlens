/// Removes AppKit's hidden Option alternates, such as "Quit and Keep Windows"
/// (⌥⌘Q) next to "Quit" (⌘Q).
///
/// A menu shows only one of the two at a time, but the Accessibility API
/// reports both as ordinary items and has no attribute that marks the
/// alternate. An entry counts as one when it directly follows an entry of the
/// same menu with the same key, and its modifiers are exactly that entry's
/// modifiers plus Option.
public enum OptionAlternates {
    /// `groups` with the alternates removed from each group.
    public static func removed<Element>(from groups: [MenuGroup<Element>]) -> [MenuGroup<Element>] {
        groups.map { MenuGroup(title: $0.title, items: removed(from: $0.items)) }
    }

    /// `entries` without the alternates; the order is kept.
    public static func removed<Element>(from entries: [MenuEntry<Element>]) -> [MenuEntry<Element>] {
        entries.indices.compactMap { index in
            let entry = entries[index]
            guard index > 0, isAlternate(entry.shortcut, of: entries[index - 1].shortcut) else {
                return entry
            }
            return nil
        }
    }

    private static func isAlternate(_ candidate: MenuShortcut, of primary: MenuShortcut) -> Bool {
        guard !primary.modifiers.contains(.option), candidate.modifiers == primary.modifiers.union(.option) else {
            return false
        }
        let sameMenu = candidate.menuPath.dropLast() == primary.menuPath.dropLast()
        return sameMenu && ShortcutFormatter.keySymbol(for: candidate) == ShortcutFormatter.keySymbol(for: primary)
    }
}
