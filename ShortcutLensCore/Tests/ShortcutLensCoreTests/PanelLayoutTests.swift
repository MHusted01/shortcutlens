import CoreGraphics
import ShortcutLensCore
import Testing

struct PanelLayoutTests {
    /// Round numbers so expected sizes are easy to check by hand:
    /// chrome = 2 * padding + header + divider + spacing = 60, and a section
    /// is title + rows * rowHeight, with spacing only between sections.
    private func metrics(screenFraction: Double = 1) -> PanelLayout.Metrics {
        PanelLayout.Metrics(
            padding: 10,
            headerHeight: 30,
            dividerHeight: 0,
            columnWidth: 100,
            columnSpacing: 20,
            rowHeight: 10,
            sectionTitleHeight: 20,
            sectionSpacing: 10,
            screenFraction: screenFraction
        )
    }

    private func layout(_ rowCounts: [Int], width: Double, height: Double) -> PanelLayout.Result {
        PanelLayout.layout(rowCounts: rowCounts, metrics: metrics(), visible: CGSize(width: width, height: height))
    }

    @Test func fitsOneColumnWhenTallEnough() {
        let result = layout([2, 3], width: 1000, height: 1000)

        #expect(result.columns == [[0, 1]])
        // 40 + 10 + 50 = 100 content, plus 60 chrome.
        #expect(result.size == CGSize(width: 120, height: 160))
        #expect(!result.scrolls)
    }

    @Test func usesMoreColumnsWhenTooTall() {
        let result = layout([2, 3, 2], width: 1000, height: 160)

        #expect(result.columns.count == 2)
        #expect(result.columns.flatMap(\.self) == [0, 1, 2])
        #expect(result.size == CGSize(width: 240, height: 160))
        #expect(!result.scrolls)
    }

    @Test func spacingBelowTheLastSectionDoesNotCount() {
        // Exactly 100 tall without the spacing below the second section.
        let result = layout([2, 3], width: 1000, height: 160)

        #expect(result.columns == [[0, 1]])
        #expect(!result.scrolls)
    }

    @Test func scrollsWhenTheWidestLayoutIsStillTooTall() {
        let result = layout([20, 20], width: 240, height: 160)

        #expect(result.columns == [[0], [1]])
        #expect(result.size == CGSize(width: 240, height: 160))
        #expect(result.scrolls)
    }

    @Test func toleratesAScreenSmallerThanTheChrome() {
        let result = layout([3], width: 50, height: 40)

        #expect(result.columns == [[0]])
        #expect(result.size == CGSize(width: 120, height: 60))
        #expect(result.scrolls)
    }

    @Test func appliesTheScreenFraction() {
        let visible = CGSize(width: 1000, height: 320)

        let full = PanelLayout.layout(rowCounts: [2, 3, 2], metrics: metrics(), visible: visible)
        let half = PanelLayout.layout(rowCounts: [2, 3, 2], metrics: metrics(screenFraction: 0.5), visible: visible)

        #expect(full.columns.count == 1)
        #expect(half.columns.count == 2)
    }

    @Test func emptyContentHasNoColumns() {
        let result = layout([], width: 1000, height: 1000)

        #expect(result.columns.isEmpty)
        #expect(!result.scrolls)
    }
}
