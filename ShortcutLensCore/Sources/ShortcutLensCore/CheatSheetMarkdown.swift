import Foundation

/// An app's shortcuts as a Markdown cheat sheet: one table per section, in
/// overlay order. Disabled state is left out because it only describes the
/// moment of the read, e.g. which document was open.
public enum CheatSheetMarkdown {
    /// Shown instead of tables when the app has no shortcut.
    public static let emptyText = "No shortcuts."
    static let customNote = "App Shortcut"

    /// Characters that Markdown could read as formatting, links, HTML or a
    /// table cell border.
    private static let specialCharacters: Set<Character> = ["\\", "`", "*", "_", "[", "]", "<", "|", "#", "~"]

    public static func render(_ content: OverlayContent<some Any>) -> String {
        let title = "# \(escape(content.appName)) shortcuts"
        guard !content.isEmpty else {
            return "\(title)\n\n\(emptyText)\n"
        }
        return ([title] + content.sections.map(table)).joined(separator: "\n\n") + "\n"
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
        let base = name.isEmpty ? "Shortcuts" : "\(name) Shortcuts"
        return "\(base).\(pathExtension)"
    }

    /// A section heading and its table. The note column appears only when
    /// one of the section's rows has a note.
    private static func table(_ section: OverlaySection<some Any>) -> String {
        let hasNotes = section.rows.contains { note(for: $0) != nil }
        let header = hasNotes
            ? ["| Shortcut | Command | Note |", "| --- | --- | --- |"]
            : ["| Shortcut | Command |", "| --- | --- |"]
        let rows = section.rows.map { row in
            tableRow([row.keys, row.title] + (hasNotes ? [note(for: row) ?? ""] : []))
        }
        return (["## \(escape(section.title))", ""] + header + rows).joined(separator: "\n")
    }

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
