import Foundation

public extension OverlayContent {
    /// The title of the section that lists the favourites.
    static var favouritesTitle: String {
        String(localized: "Favourites", bundle: .module)
    }

    /// A copy with a first Favourites section that lists the menu rows at
    /// `paths`, in that order. The originals stay in their sections and are
    /// marked `isFavourite`. Paths without a menu row are skipped; with none
    /// left, no section is added. A previous Favourites section is replaced,
    /// so this can be applied again after the favourites change.
    func pinning(_ paths: [[String]]) -> Self {
        let unpinned = sections.filter { !$0.isPinned }
        // Only the first row with a path is pinned, so only it gets the star.
        let starred = Set(paths.compactMap { path in
            unpinned.lazy.compactMap { section in
                section.rows.first { $0.canBeFavourite && $0.menuPath == path }.map { [section.id, $0.id] }
            }.first
        })
        let base = unpinned.map { section in
            OverlaySection(id: section.id, title: section.title, rows: section.rows.map { row in
                row.with(isFavourite: starred.contains([section.id, row.id]))
            })
        }
        let rows = base.flatMap(\.rows)
        let pinned = paths
            .compactMap { path in rows.first { $0.isFavourite && $0.menuPath == path } }
            .enumerated()
            .map { $0.element.with(id: $0.offset) }
        let favourites = pinned.isEmpty
            ? []
            : [OverlaySection(id: 0, title: Self.favouritesTitle, rows: pinned, isPinned: true)]
        let renumbered = (favourites + base).enumerated().map { offset, section in
            OverlaySection(id: offset, title: section.title, rows: section.rows, isPinned: section.isPinned)
        }
        return Self(appName: appName, sections: renumbered).markingConflicts()
    }
}
