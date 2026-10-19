import Foundation

/// Filters and ranks overlay rows against a typed search query.
///
/// Matching ignores case and diacritics (`é` matches `e`, `å` matches `a`).
/// `æ` and `ø` are letters of their own, not decomposable, so they only match
/// themselves. Sections keep menu bar order and their ids; sections without a
/// match are dropped.
public enum ShortcutMatcher {
    /// How well a title matches, best first.
    private enum Rank: Int, Comparable {
        case titlePrefix
        case wordPrefix
        case substring
        case subsequence
        /// The row's section title matched, the row itself did not.
        case section

        static func < (lhs: Rank, rhs: Rank) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The rows of `content` that match `query`, best match first within
    /// each section; ties keep menu order. An empty query returns `content`.
    public static func filter<Element>(_ content: OverlayContent<Element>, query: String) -> OverlayContent<Element> {
        let needle = normalized(query)
        guard !needle.isEmpty else { return content }
        let sections = content.sections.compactMap { filtered($0, needle: needle) }
        return OverlayContent(appName: content.appName, sections: sections)
    }

    /// A matching row with what it is sorted by.
    private struct Candidate<Element> {
        let rank: Rank
        /// Menu order, the tie-breaker.
        let offset: Int
        let row: OverlayRow<Element>
    }

    private static func filtered<Element>(
        _ section: OverlaySection<Element>,
        needle: String
    ) -> OverlaySection<Element>? {
        // Section titles need a contiguous match; fuzzy matching short menu
        // names like "File" would pull in whole menus for most queries.
        let sectionRank: Rank? = contiguousRank(normalized(section.title), needle) == nil ? nil : .section
        let candidates = section.rows.enumerated().compactMap { offset, row -> Candidate<Element>? in
            guard let rank = rank(normalized(row.title), needle) ?? sectionRank else { return nil }
            return Candidate(rank: rank, offset: offset, row: row)
        }
        guard !candidates.isEmpty else { return nil }
        let rows = candidates.sorted { ($0.rank, $0.offset) < ($1.rank, $1.offset) }.map(\.row)
        return OverlaySection(id: section.id, title: section.title, rows: rows, isPinned: section.isPinned)
    }

    private static func rank(_ title: String, _ needle: String) -> Rank? {
        contiguousRank(title, needle) ?? (isSubsequence(needle, of: title) ? .subsequence : nil)
    }

    /// The best rank among all occurrences of `needle` in `title`.
    private static func contiguousRank(_ title: String, _ needle: String) -> Rank? {
        var best: Rank?
        var searchStart = title.startIndex
        while let range = title.range(of: needle, range: searchStart ..< title.endIndex) {
            if range.lowerBound == title.startIndex {
                return .titlePrefix
            }
            let previous = title[title.index(before: range.lowerBound)]
            if !previous.isLetter, !previous.isNumber {
                return .wordPrefix
            }
            best = .substring
            searchStart = title.index(after: range.lowerBound)
        }
        return best
    }

    /// Whether the query's characters, ignoring spaces, appear in order in `title`.
    private static func isSubsequence(_ needle: String, of title: String) -> Bool {
        var remaining = title.makeIterator()
        return needle.filter { !$0.isWhitespace }.allSatisfy { character in
            while let next = remaining.next() {
                if next == character {
                    return true
                }
            }
            return false
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
