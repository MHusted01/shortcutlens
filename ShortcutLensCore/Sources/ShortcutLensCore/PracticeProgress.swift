/// How well each menu item's shortcut is known, per app, as Leitner boxes.
///
/// An item is named by its menu path, like a favourite, so progress survives
/// an App Shortcut change. A right answer moves the item up one box, a wrong
/// one sends it back to the first. Items never asked have no box. Menu titles
/// are localised, so progress only matches in the UI language it was made in.
public struct PracticeProgress: Equatable, Sendable {
    /// The store key; the value is `[bundleID: [["path": [String], "box": Int]]]`.
    public static let storeKey = "practiceProgress"
    public static let boxes = 1 ... 5

    public static let empty = Self(entries: [:])

    private static let pathKey = "path"
    private static let boxKey = "box"

    private let entries: [String: [[String]: Int]]

    private init(entries: [String: [[String]: Int]]) {
        self.entries = entries
    }

    /// The progress in `store`. A value of the wrong type loads as no
    /// progress; entries with an empty path or a box out of range are
    /// skipped, and a repeated path keeps its first box.
    public init(store: SettingsStore) {
        let raw = store.object(forKey: Self.storeKey) as? [String: Any] ?? [:]
        self.init(entries: raw.compactMapValues { value in
            let boxes = (value as? [Any] ?? []).compactMap(Self.entry).reduce(into: [[String]: Int]()) {
                $0[$1.path] = $0[$1.path] ?? $1.box
            }
            return boxes.isEmpty ? nil : boxes
        })
    }

    public func save(to store: SettingsStore) {
        store.set(entries.mapValues { boxes in
            boxes.map { [Self.pathKey: $0.key, Self.boxKey: $0.value] as [String: Any] }
        }, forKey: Self.storeKey)
    }

    /// The item's box, or nil when it was never asked.
    public func box(for path: [String], bundleID: String?) -> Int? {
        bundleID.flatMap { entries[$0]?[path] }
    }

    public func hasProgress(bundleID: String?) -> Bool {
        bundleID.flatMap { entries[$0] }.map { !$0.isEmpty } ?? false
    }

    /// A copy with one answer recorded. Apps without a bundle ID and empty
    /// paths cannot be stored and leave the progress unchanged.
    public func recording(correct: Bool, for path: [String], bundleID: String?) -> Self {
        guard let bundleID, !path.isEmpty else {
            return self
        }
        let current = box(for: path, bundleID: bundleID) ?? Self.boxes.lowerBound
        let box = correct ? min(current + 1, Self.boxes.upperBound) : Self.boxes.lowerBound
        let boxes = (entries[bundleID] ?? [:]).merging([path: box]) { _, new in new }
        return Self(entries: entries.merging([bundleID: boxes]) { _, new in new })
    }

    /// A copy without any progress for the app with `bundleID`.
    public func resetting(bundleID: String?) -> Self {
        guard let bundleID else {
            return self
        }
        return Self(entries: entries.filter { $0.key != bundleID })
    }

    private static func entry(_ value: Any) -> (path: [String], box: Int)? {
        guard let entry = value as? [String: Any],
              let path = entry[pathKey] as? [String], !path.isEmpty,
              let box = entry[boxKey] as? Int, boxes.contains(box)
        else {
            return nil
        }
        return (path, box)
    }
}
