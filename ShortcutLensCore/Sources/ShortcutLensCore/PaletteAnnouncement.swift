import Foundation

/// What VoiceOver says for the overlay. In the palette the search field keeps
/// keyboard focus while the arrow keys move the selection, so VoiceOver does
/// not follow the selection by itself; the app announces these texts instead.
public enum PaletteAnnouncement {
    /// A row's accessibility label: title, spoken keys, then its markers.
    /// Rows in the pinned section are all favourites, so they leave that out.
    public static func rowLabel(_ row: OverlayRow<some Any>, inPinnedSection: Bool) -> String {
        let favourite = row.isFavourite && !inPinnedSection ? [String(localized: "favourite", bundle: .module)] : []
        let custom = row.isCustom ? [String(localized: "custom shortcut", bundle: .module)] : []
        let conflict = row.conflict.map { [$0] } ?? []
        let keys = SpokenKeys.label(for: row.keys)
        return ([row.title] + (keys.isEmpty ? [] : [keys]) + favourite + custom + conflict).joined(separator: ", ")
    }

    /// The text for the palette changing from `before` (nil: just opened) to
    /// `after`, or nil when nothing worth saying changed.
    /// - Content arrived: the app name and the number of shortcuts.
    /// - Query changed: the number of matches.
    /// - Selection moved: the selected row.
    public static func text<Element>(from before: PaletteState<Element>?, to after: PaletteState<Element>) -> String? {
        guard let visible = after.visible else {
            return nil
        }
        guard let before, before.content != nil else {
            return "\(visible.appName), \(shortcutCount(visible.rowCount))"
        }
        if before.query != after.query {
            return visible.isEmpty
                ? String(localized: "No matching shortcuts", bundle: .module)
                : shortcutCount(visible.rowCount)
        }
        guard before.selection != after.selection, let selection = after.selection, let row = after.selectedRow else {
            return nil
        }
        let isPinned = visible.sections.first { $0.id == selection.section }?.isPinned ?? false
        return rowLabel(row, inPinnedSection: isPinned)
    }

    /// "1 shortcut", "3 shortcuts": in the app's language, or in `locale`'s
    /// when one is given (for tests).
    public static func shortcutCount(_ rows: Int, locale: Locale? = nil) -> String {
        var resource = LocalizedStringResource("\(rows) shortcuts", bundle: .atURL(Bundle.module.bundleURL))
        if let locale {
            resource.locale = locale
        }
        return String(localized: resource)
    }
}
