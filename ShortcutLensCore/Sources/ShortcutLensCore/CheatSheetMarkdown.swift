import Foundation

/// An app's shortcuts as a Markdown cheat sheet: one table per section, in
/// overlay order. Disabled state is left out because it only describes the
/// moment of the read, e.g. which document was open.
public enum CheatSheetMarkdown {
    /// Shown instead of tables when the app has no shortcut.
    public static let emptyText = String(localized: "No shortcuts.", bundle: .module)
    static let customNote = String(localized: "App Shortcut", bundle: .module)

    /// Characters that Markdown could read as formatting, links, HTML or a
    /// table cell border or an HTML entity.
    private static let specialCharacters: Set<Character> = ["\\", "`", "*", "_", "[", "]", "<", "&", "|", "#", "~"]

    public static func render(_ content: OverlayContent<some Any>) -> String {
        let title = "# \(escape(title(appName: content.appName)))"
        guard !content.isEmpty else {
            return "\(title)\n\n\(emptyText)\n"
        }
        return ([title] + content.sections.map(table)).joined(separator: "\n\n") + "\n"
    }

    /// The sheet's title, e.g. "Safari shortcuts"; just "Shortcuts" for an
    /// app without a name.
    public static func title(appName: String) -> String {
        let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? untitled : String(localized: "\(name) shortcuts", bundle: .module)
    }

    /// What the row's note says: whether it is an App Shortcut and what else
    /// uses its keys; nil when there is nothing to say.
    public static func note(for row: OverlayRow<some Any>) -> String? {
        let parts = [row.isCustom ? customNote : nil, row.conflict].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    /// A file name for the app's cheat sheet without path separators, colons
    /// or a leading dot, e.g. "Safari Shortcuts.md".
    public static func fileName(appName: String, pathExtension: String) -> String {
        let name = String(appName.map { $0 == "/" || $0 == ":" ? "-" : $0 })
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop { $0 == "." }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = name.isEmpty ? untitled : String(localized: "\(name) Shortcuts", bundle: .module)
        return "\(base).\(pathExtension)"
    }

    /// A section heading and its table. The note column appears only when
    /// one of the section's rows has a note.
    private static func table(_ section: OverlaySection<some Any>) -> String {
        let hasNotes = section.rows.contains { note(for: $0) != nil }
        let columns = [shortcutColumn, commandColumn] + (hasNotes ? [noteColumn] : [])
        let header = [tableRow(columns), "|" + String(repeating: " --- |", count: columns.count)]
        let rows = section.rows.map { row in
            tableRow([KeyDisplay.text(for: row.keys), row.displayTitle] + (hasNotes ? [note(for: row) ?? ""] : []))
        }
        return (["## \(escape(section.title))", ""] + header + rows).joined(separator: "\n")
    }

    /// Title and file name for an app without a name.
    private static let untitled = String(localized: "Shortcuts", bundle: .module)
    private static let shortcutColumn = String(localized: "Shortcut", bundle: .module)
    private static let commandColumn = String(localized: "Command", bundle: .module, comment: "The menu command")
    private static let noteColumn = String(localized: "Note", bundle: .module)

    /// One table row of escaped cells; an empty cell is a single space.
    private static func tableRow(_ cells: [String]) -> String {
        "|" + cells.map { $0.isEmpty ? " " : " \(escape($0)) " }.joined(separator: "|") + "|"
    }

    /// `text` on one line with Markdown's special characters escaped.
    static func escape(_ text: String) -> String {
        let oneLine = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return oneLine.reduce(into: "") { result, character in
            if specialCharacters.contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
    }
}
