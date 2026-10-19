/// Layout of the printed cheat sheet, which shows each row as keys, a tab
/// and the command.
public enum CheatSheetLayout {
    /// Where the command column starts at the earliest.
    public static let minimumCommandIndent = 90.0
    /// Space between the widest keys and the command column.
    public static let columnGap = 12.0

    /// Past the widest keys, so a long key word such as "⌃⌥⇧⌘Mellemrum" does
    /// not push its command to the next default tab stop, but no later than
    /// half the page, so the command keeps room.
    public static func commandIndent(keyWidths: [Double], pageWidth: Double) -> Double {
        let indent = max(minimumCommandIndent, (keyWidths.max() ?? 0) + columnGap)
        return min(indent, pageWidth / 2)
    }
}
