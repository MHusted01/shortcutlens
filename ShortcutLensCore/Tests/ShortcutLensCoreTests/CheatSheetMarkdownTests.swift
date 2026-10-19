import Foundation
import ShortcutLensCore
import Testing

struct CheatSheetMarkdownTests {
    private func row(
        _ id: Int, _ title: String, keys: String, isCustom: Bool = false, conflict: String? = nil
    ) -> OverlayRow<Int> {
        OverlayRow(id: id, title: title, keys: keys, isCustom: isCustom, conflict: conflict, element: nil)
    }

    private func content(_ sections: [(String, [OverlayRow<Int>])], appName: String = "App") -> OverlayContent<Int> {
        OverlayContent(
            appName: appName,
            sections: sections.enumerated().map {
                OverlaySection(id: $0.offset, title: $0.element.0, rows: $0.element.1)
            }
        )
    }

    private static func fixture(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func rendersSectionsAsTablesMatchingTheFixture() throws {
        let sheet = content([
            ("File", [row(0, "New", keys: "⌘N"), row(1, "Duplicate", keys: "⇧⌘S")]),
            ("Edit", [
                row(0, "Undo", keys: "⌘Z"),
                row(1, "Lock", keys: "⌃⌘Q", isCustom: true, conflict: "Also used by System > Lock Screen"),
            ]),
            ("System", [row(0, "Lock Screen", keys: "⌃⌘Q", conflict: "Also used by Edit > Lock")]),
        ], appName: "TextEdit")

        #expect(try CheatSheetMarkdown.render(sheet) == Self.fixture("cheatsheet-basic"))
    }

    @Test func escapesMarkdownInTitlesAndKeys() {
        let rows = [
            row(0, "Show `raw` [1] <b>_x_</b>", keys: "⇧⌘|"),
            row(1, "Back", keys: "⌘\\"),
            row(2, "Copy &amp; Paste", keys: "⌘V"),
        ]
        let sheet = content([("View *all* | more", rows)])

        let lines = CheatSheetMarkdown.render(sheet).split(separator: "\n")

        #expect(lines.contains(#"## View \*all\* \| more"#))
        #expect(lines.contains(#"| ⇧⌘\| | Show \`raw\` \[1\] \<b>\_x\_\</b> |"#))
        #expect(lines.contains(#"| ⌘\\ | Back |"#))
        #expect(lines.contains(#"| ⌘V | Copy \&amp; Paste |"#))
    }

    @Test func escapesTheAppNameAndJoinsLineBreaks() {
        let sheet = content([("Fi\nle", [row(0, "Save\r\nAll", keys: "⌘S")])], appName: "#1 *App*")

        let lines = CheatSheetMarkdown.render(sheet).split(separator: "\n")

        #expect(lines.first == ##"# \#1 \*App\* shortcuts"##)
        #expect(lines.contains("## Fi le"))
        #expect(lines.contains("| ⌘S | Save All |"))
    }

    @Test func saysSoWhenThereIsNothingToExport() {
        #expect(CheatSheetMarkdown.render(content([], appName: "Finder")) == "# Finder shortcuts\n\nNo shortcuts.\n")
    }

    @Test(arguments: [("Safari", "Safari shortcuts"), ("", "Shortcuts"), (" \n", "Shortcuts")])
    func titlesTheSheetEvenWithoutAnAppName(appName: String, expected: String) {
        #expect(CheatSheetMarkdown.title(appName: appName) == expected)
        #expect(CheatSheetMarkdown.render(content([], appName: appName)).hasPrefix("# \(expected)\n"))
    }

    @Test func notesNameTheAppShortcutAndTheConflict() {
        #expect(CheatSheetMarkdown.note(for: row(0, "A", keys: "⌘A")) == nil)
        #expect(CheatSheetMarkdown.note(for: row(0, "A", keys: "⌘A", isCustom: true)) == "App Shortcut")
        #expect(CheatSheetMarkdown.note(for: row(0, "A", keys: "⌘A", conflict: "Also used by B")) == "Also used by B")
    }

    @Test(arguments: [
        ("Safari", "Safari Shortcuts.md"),
        ("Foo/Bar: Baz", "Foo-Bar- Baz Shortcuts.md"),
        (".hidden", "hidden Shortcuts.md"),
        ("  ", "Shortcuts.md"),
        ("", "Shortcuts.md"),
    ])
    func suggestsASafeFileName(appName: String, expected: String) {
        #expect(CheatSheetMarkdown.fileName(appName: appName, pathExtension: "md") == expected)
    }
}
