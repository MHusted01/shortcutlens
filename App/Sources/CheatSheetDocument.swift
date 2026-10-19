import AppKit
import ShortcutLensCore

/// The printable cheat sheet: the same sections and notes as the Markdown
/// export, laid out as text with a keys column. The text view paginates.
@MainActor
enum CheatSheetDocument {
    /// Where the command column starts, after the keys.
    private static let commandIndent: CGFloat = 90
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
        let text = NSMutableAttributedString()
        text.append(line(CheatSheetMarkdown.title(appName: content.appName), font: titleFont, spacingAfter: 8))
        if content.isEmpty {
            text.append(line(CheatSheetMarkdown.emptyText, font: rowFont))
        }
        for section in content.sections {
            text.append(line(section.title, font: headingFont, spacingBefore: 12, spacingAfter: 4))
            for row in section.rows {
                text.append(line("\(row.keys)\t\(row.title)", font: rowFont))
                if let note = CheatSheetMarkdown.note(for: row) {
                    text.append(line("\t\(note)", font: noteFont, color: noteColor))
                }
            }
        }
        return text
    }

    private static func line(
        _ string: String,
        font: NSFont,
        color: NSColor = textColor,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .left, location: commandIndent)]
        style.paragraphSpacingBefore = spacingBefore
        style.paragraphSpacing = spacingAfter
        return NSAttributedString(
            string: string + "\n",
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]
        )
    }
}
