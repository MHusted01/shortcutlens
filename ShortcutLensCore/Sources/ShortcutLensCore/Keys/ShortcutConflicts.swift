import Foundation

/// Finds key combinations that more than one shortcut uses, within an app or
/// between an app and the system.
///
/// Disabled menu items count: they still own their keys, and an app that
/// enables one of two items on the same keys can run either.
public enum ShortcutConflicts {
    /// A shortcut and where it is listed, e.g. `File > Close`.
    public struct Entry: Sendable {
        public let combo: KeyCombo?
        public let location: String

        public init(combo: KeyCombo?, location: String) {
            self.combo = combo
            self.location = location
        }
    }

    /// The other shortcuts on the same keys: the first few by location, and
    /// how many there are in all.
    public struct Clashes: Equatable, Sendable {
        public static let none = Self(shown: [], total: 0)

        /// At most `shownLimit` locations, in input order.
        public let shown: [String]
        public let total: Int

        public init(shown: [String], total: Int) {
            self.shown = shown
            self.total = total
        }

        public var isEmpty: Bool {
            total == 0
        }
    }

    /// Locations named in an explanation; the rest are counted. Keeps the
    /// line readable and the work per row small however many rows share keys.
    public static let shownLimit = 3
    /// Characters kept of a section or item title in a location.
    public static let titleLimit = 60

    /// Where a row is listed, e.g. `File > Close`, with each title shortened
    /// to `titleLimit` characters.
    public static func location(section: String, title: String) -> String {
        "\(shortened(section)) > \(shortened(title))"
    }

    /// For each entry, the other entries with its combo, in input order.
    /// Entries without a combo clash with nothing. Entries are told apart by
    /// position, so two items with the same title still clash.
    public static func clashes(among entries: [Entry]) -> [Clashes] {
        let indexed = entries.enumerated().filter { $0.element.combo != nil }
        let byCombo = Dictionary(grouping: indexed) { $0.element.combo }
        return entries.enumerated().map { index, entry in
            guard let combo = entry.combo, let group = byCombo[combo], group.count > 1 else {
                return .none
            }
            // Stops after `shownLimit` peers, so a large group costs little per row.
            let shown = group.lazy.filter { $0.offset != index }.prefix(shownLimit).map(\.element.location)
            return Clashes(shown: Array(shown), total: group.count - 1)
        }
    }

    /// The text shown under a conflicting row; nil without clashes.
    public static func explanation(for clashes: Clashes) -> String? {
        guard !clashes.isEmpty else {
            return nil
        }
        let locations = clashes.shown.joined(separator: ", ")
        let rest = clashes.total - clashes.shown.count
        return rest > 0
            ? String(localized: "Also used by \(locations) and \(rest) more", bundle: .module)
            : String(localized: "Also used by \(locations)", bundle: .module)
    }

    private static func shortened(_ title: String) -> String {
        title.count > titleLimit ? title.prefix(titleLimit - 1) + "…" : title
    }
}
