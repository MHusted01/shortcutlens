import ShortcutLensCore
import Testing

struct ShortcutMatcherTests {
    private func section(_ title: String, id: Int = 0, _ rows: [String]) -> OverlaySection<Int> {
        let rows = rows.enumerated().map { index, title in
            OverlayRow(id: index, title: title, keys: "⌘X", element: index)
        }
        return OverlaySection(id: id, title: title, rows: rows)
    }

    private func content(_ sections: OverlaySection<Int>...) -> OverlayContent<Int> {
        OverlayContent(appName: "App", sections: sections)
    }

    private func titles(_ content: OverlayContent<Int>, query: String) -> [[String]] {
        ShortcutMatcher.filter(content, query: query).sections.map { $0.rows.map(\.title) }
    }

    @Test func emptyQueryReturnsContentUnchanged() {
        let original = content(section("File", ["Save", "Open"]), section("Edit", id: 1, ["Copy"]))

        #expect(ShortcutMatcher.filter(original, query: "").sections == original.sections)
        #expect(ShortcutMatcher.filter(original, query: "  ").sections == original.sections)
    }

    @Test func ranksTitlePrefixThenWordPrefixThenSubstringThenSubsequence() {
        let original = content(section("Format", ["Paste", "Close Window", "Unicode Text", "Show Colors", "Copy"]))

        #expect(titles(original, query: "co") == [["Copy", "Show Colors", "Unicode Text", "Close Window"]])
    }

    @Test func tiesKeepMenuOrder() {
        let original = content(section("File", ["Show", "Save", "Select All"]))

        #expect(titles(original, query: "s") == [["Show", "Save", "Select All"]])
    }

    @Test func multiWordQueryMatchesAtWordStart() {
        let original = content(section("File", ["Paste and Match Style", "Save As…"]))

        #expect(titles(original, query: "match st") == [["Paste and Match Style"]])
        #expect(titles(original, query: "save as") == [["Save As…"]])
    }

    @Test func ignoresCase() {
        let original = content(section("File", ["Save As…", "Open"]))

        #expect(titles(original, query: "SAVE") == [["Save As…"]])
    }

    @Test func ignoresDiacriticsBothWays() {
        let original = content(section("Edit", ["Résumé", "Café", "Åbn"]))

        #expect(titles(original, query: "resume") == [["Résumé"]])
        #expect(titles(original, query: "CAFÉ") == [["Café"]])
        #expect(titles(original, query: "abn") == [["Åbn"]])
        #expect(titles(original, query: "åbn") == [["Åbn"]])
    }

    /// Æ and Ø are letters of their own in Danish and Norwegian, not A or O
    /// with a diacritic.
    @Test func treatsAeAndOSlashAsDistinctLetters() {
        let original = content(section("Edit", ["Æble", "Øl", "Ol"]))

        #expect(titles(original, query: "ae").isEmpty)
        #expect(titles(original, query: "æ") == [["Æble"]])
        #expect(titles(original, query: "ø") == [["Øl"]])
        #expect(titles(original, query: "ol") == [["Ol"]])
    }

    @Test func sectionTitleMatchIncludesItsRowsBelowDirectMatches() {
        let original = content(
            section("Edit", ["Undo", "Copy", "Edit Link"]),
            section("File", id: 1, ["Close"])
        )

        #expect(titles(original, query: "edit") == [["Edit Link", "Undo", "Copy"]])
    }

    @Test func sectionTitleNeedsContiguousMatch() {
        let original = content(section("File", ["Save"]))

        #expect(titles(original, query: "fl").isEmpty)
    }

    @Test func hidesSectionsWithoutMatchesAndKeepsIdentity() {
        let original = content(section("File", ["Save", "Open"]), section("View", id: 1, ["Zoom", "Show Tab Bar"]))

        let filtered = ShortcutMatcher.filter(original, query: "show")

        #expect(filtered.appName == "App")
        #expect(filtered.sections.map(\.id) == [1])
        #expect(filtered.sections[0].title == "View")
        #expect(filtered.sections[0].rows == [OverlayRow(id: 1, title: "Show Tab Bar", keys: "⌘X", element: 1)])
    }

    @Test func noMatchesGiveEmptyContent() {
        let filtered = ShortcutMatcher.filter(content(section("File", ["Save"])), query: "xyz")

        #expect(filtered.isEmpty)
        #expect(filtered.rowCount == 0)
    }
}
