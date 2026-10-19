/// Shortcuts for one app that are not in its menus, read from a local JSON
/// file. See `docs/packs.md` for the file format.
public struct ShortcutPack: Hashable, Sendable {
    /// The app the pack is for, e.g. `com.apple.finder`.
    public let bundleIdentifier: String
    /// A display name; optional in the file.
    public let name: String?
    public let sections: [PackSection]

    public init(bundleIdentifier: String, name: String?, sections: [PackSection]) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.sections = sections
    }
}

/// One titled group of display-only shortcuts. Each shortcut's `menuPath` is
/// `[section title, shortcut title]`, like a menu item's.
public struct PackSection: Hashable, Sendable {
    public let title: String
    public let shortcuts: [MenuShortcut]

    public init(title: String, shortcuts: [MenuShortcut]) {
        self.title = title
        self.shortcuts = shortcuts
    }
}

/// Why a pack file was not loaded. Fields are named by their JSON path, e.g.
/// `sections[0].shortcuts[2].key`.
public enum PackError: Error, Hashable, Sendable {
    case invalidJSON
    case tooLarge
    case unsupportedVersion(Int)
    case missingField(String)
    case invalidValue(field: String, reason: String)

    /// A sentence for the Settings window.
    public var message: String {
        switch self {
        case .invalidJSON:
            "Not valid JSON."
        case .tooLarge:
            "File is larger than \(ShortcutPackParser.maxFileSize / 1024) KB."
        case let .unsupportedVersion(version):
            "Unsupported schemaVersion \(version); this version reads \(ShortcutPackParser.schemaVersion)."
        case let .missingField(field):
            "Missing field \"\(field)\"."
        case let .invalidValue(field, reason):
            "Invalid \"\(field)\": \(reason)."
        }
    }
}
