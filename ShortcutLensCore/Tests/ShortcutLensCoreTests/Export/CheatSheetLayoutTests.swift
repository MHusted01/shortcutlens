import ShortcutLensCore
import Testing

struct CheatSheetLayoutTests {
    private let pageWidth = 468.0

    @Test func narrowKeysKeepTheMinimumIndent() {
        #expect(CheatSheetLayout.commandIndent(keyWidths: [20, 74], pageWidth: pageWidth) == 90)
    }

    @Test func noRowsKeepTheMinimumIndent() {
        #expect(CheatSheetLayout.commandIndent(keyWidths: [], pageWidth: pageWidth) == 90)
    }

    /// `⌃⌥⇧⌘Mellemrum` at 11 pt.
    @Test func wideKeysMoveTheColumnPastTheWidest() {
        #expect(CheatSheetLayout.commandIndent(keyWidths: [30, 99.5], pageWidth: pageWidth) == 111.5)
    }

    @Test func theColumnStartsNoLaterThanHalfThePage() {
        #expect(CheatSheetLayout.commandIndent(keyWidths: [400], pageWidth: pageWidth) == 234)
    }
}
