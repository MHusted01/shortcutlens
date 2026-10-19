/// The menu items the user pinned, per app, in the order they were added.
///
/// An item is named by its menu path (`["File", "Save"]`), not its keys, so a
/// favourite survives an App Shortcut change. A path that is no longer in the
/// menus is kept; the overlay just has no row to pin for it. Menu titles are
/// localised, so favourites only match in the UI language they were made in.
public struct Favourites: Equatable, Sendable {
    /// The store key; the value is `[bundleID: [[menu title]]]`.
    public static let storeKey = "favourites"

    public static let empty = Self(paths: [:])

    private let paths: [String: [[String]]]

    private init(paths: [String: [[String]]]) {
        self.paths = paths
    }

    /// The favourites in `store`. A value of the wrong type loads as no
    /// favourites; malformed apps or paths are skipped, duplicates dropped.
    public init(store: SettingsStore) {
        let raw = store.object(forKey: Self.storeKey) as? [String: Any] ?? [:]
        self.init(paths: raw.compactMapValues { value in
            let paths = (value as? [Any] ?? []).compactMap { $0 as? [String] }.filter { !$0.isEmpty }
            let unique = paths.enumerated().filter { !paths.prefix($0.offset).contains($0.element) }.map(\.element)
            return unique.isEmpty ? nil : unique
        })
    }

    public func save(to store: SettingsStore) {
        store.set(paths, forKey: Self.storeKey)
    }

    /// The favourite paths of the app with `bundleID`, oldest first.
    public func paths(for bundleID: String?) -> [[String]] {
        bundleID.flatMap { paths[$0] } ?? []
    }

    public func contains(_ path: [String], bundleID: String?) -> Bool {
        paths(for: bundleID).contains(path)
    }

    /// A copy with `path` added after the others, or removed when it is
    /// already a favourite. Apps without a bundle ID and empty paths cannot
    /// be stored and leave the favourites unchanged.
    public func toggling(_ path: [String], bundleID: String?) -> Self {
        guard let bundleID, !path.isEmpty else {
            return self
        }
        let current = paths(for: bundleID)
        let updated = current.contains(path) ? current.filter { $0 != path } : current + [path]
        return Self(paths: paths.filter { $0.key != bundleID }.merging(
            updated.isEmpty ? [:] : [bundleID: updated]
        ) { _, new in new })
    }
}
