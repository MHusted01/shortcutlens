import Foundation

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
    case invalidValue(field: String, reason: Reason)

    /// What is wrong with a value. Kept apart from the text so errors compare
    /// equal in any language.
    public enum Reason: Hashable, Sendable {
        case empty
        case wrongType
        case unknownKey(String)
        case unknownModifier(String)

        var text: String {
            switch self {
            case .empty:
                String(localized: "must not be empty", bundle: .module)
            case .wrongType:
                String(localized: "wrong type", bundle: .module)
            case let .unknownKey(key):
                String(localized: "unknown key \"\(key)\"", bundle: .module)
            case let .unknownModifier(name):
                String(localized: "unknown modifier \"\(name)\"", bundle: .module)
            }
        }
    }

    /// The schema version this build reads.
    private static let readable = ShortcutPackParser.schemaVersion

    /// A sentence for the Settings window.
    public var message: String {
        switch self {
        case .invalidJSON:
            String(localized: "Not valid JSON.", bundle: .module)
        case .tooLarge:
            String(localized: "File is larger than \(ShortcutPackParser.maxFileSize / 1024) KB.", bundle: .module)
        case let .unsupportedVersion(version):
            String(
                localized: "Unsupported schemaVersion \(version); this version reads \(Self.readable).",
                bundle: .module
            )
        case let .missingField(field):
            String(localized: "Missing field \"\(field)\".", bundle: .module)
        case let .invalidValue(field, reason):
            String(localized: "Invalid \"\(field)\": \(reason.text).", bundle: .module)
        }
    }
}
