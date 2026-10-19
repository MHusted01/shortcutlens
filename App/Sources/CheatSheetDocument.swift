import AppKit
import ShortcutLensCore

/// The printable cheat sheet: the same sections and notes as the Markdown
/// export, laid out as text with a keys column. The text view paginates.
@MainActor
enum CheatSheetDocument {
    /// Where the command column starts at the earliest, after the keys.
    private static let minimumCommandIndent: CGFloat = 90
    /// Space between the widest keys and the command column.
    private static let columnGap: CGFloat = 12
    private static let titleFont = NSFont.boldSystemFont(ofSize: 18)
    private static let headingFont = NSFont.boldSystemFont(ofSize: 13)
    private static let rowFont = NSFont.systemFont(ofSize: 11)
    private static let noteFont = NSFont.systemFont(ofSize: 9)
    // Fixed colours: paper is white even when the Mac uses Dark Mode.
    private static let textColor = NSColor.black
    private static let noteColor = NSColor.darkGray

    /// A print operation for `content`; `jobTitle` names the PDF that Save
    /// as PDF suggests.
    static func printOperation(for content: OverlayContent<AXUIElement>, jobTitle: String) -> NSPrintOperation {
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        view.drawsBackground = false
        view.textStorage?.setAttributedString(text(for: content))
        view.sizeToFit()
        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.jobTitle = jobTitle
        return operation
    }

    static func text(for content: OverlayContent<AXUIElement>) -> NSAttributedString {
        let indent = commandIndent(for: content)
        let text = NSMutableAttributedString()
        text.append(line(CheatSheetMarkdown.title(appName: content.appName), font: titleFont, spacingAfter: 8))
        if content.isEmpty {
            text.append(line(CheatSheetMarkdown.emptyText, font: rowFont))
        }
        for section in content.sections {
            text.append(line(section.title, font: headingFont, spacingBefore: 12, spacingAfter: 4))
            for row in section.rows {
                let keys = KeyDisplay.text(for: row.keys)
                text.append(line("\(keys)\t\(row.displayTitle)", font: rowFont, indent: indent))
                if let note = CheatSheetMarkdown.note(for: row) {
                    text.append(line("\t\(note)", font: noteFont, color: noteColor, indent: indent))
                }
            }
        }
        return text
    }

    /// Past the widest keys, so a long key word such as "⌃⌥⇧⌘Mellemrum" does
    /// not push its title to the next default tab stop.
    private static func commandIndent(for content: OverlayContent<AXUIElement>) -> CGFloat {
        let widths = content.sections.flatMap(\.rows).map { row in
            (KeyDisplay.text(for: row.keys) as NSString).size(withAttributes: [.font: rowFont]).width
        }
        return max(minimumCommandIndent, (widths.max() ?? 0) + columnGap)
    }

    private static func line(
        _ string: String,
        font: NSFont,
        color: NSColor = textColor,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0,
        indent: CGFloat = minimumCommandIndent
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
        style.paragraphSpacingBefore = spacingBefore
        style.paragraphSpacing = spacingAfter
        return NSAttributedString(
            string: string + "\n",
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]
        )
    }
}
