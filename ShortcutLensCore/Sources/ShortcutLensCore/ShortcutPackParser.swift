import Foundation

/// Reads a `ShortcutPack` from JSON. Every problem becomes a `PackError`;
/// nothing traps on bad input.
public enum ShortcutPackParser {
    /// The only schema version this build reads.
    public static let schemaVersion = 1
    /// Files above this size are rejected unread.
    public static let maxFileSize = 256 * 1024

    public static func parse(_ data: Data) -> Result<ShortcutPack, PackError> {
        guard data.count <= maxFileSize else {
            return .failure(.tooLarge)
        }
        // The version is checked first, so a newer file says so instead of
        // reporting fields this version does not know.
        return Result {
            let probe = try JSONDecoder().decode(VersionProbe.self, from: data)
            guard let version = probe.schemaVersion else {
                throw PackError.missingField("schemaVersion")
            }
            guard version == schemaVersion else {
                throw PackError.unsupportedVersion(version)
            }
            return try pack(from: JSONDecoder().decode(RawPack.self, from: data))
        }
        .mapError(packError)
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int?
    }

    private struct RawPack: Decodable {
        let bundleIdentifier: String
        let name: String?
        let sections: [RawSection]
    }

    private struct RawSection: Decodable {
        let title: String
        let shortcuts: [RawShortcut]
    }

    private struct RawShortcut: Decodable {
        let title: String
        let key: String
        let modifiers: [String]?
    }

    private static func pack(from raw: RawPack) throws -> ShortcutPack {
        let sections = try raw.sections.enumerated().map { index, section in
            let path = "sections[\(index)]"
            let title = try text(section.title, field: "\(path).title")
            let shortcuts = try section.shortcuts.enumerated().map { offset, shortcut in
                try self.shortcut(from: shortcut, section: title, path: "\(path).shortcuts[\(offset)]")
            }
            return PackSection(title: title, shortcuts: shortcuts)
        }
        return try ShortcutPack(
            bundleIdentifier: text(raw.bundleIdentifier, field: "bundleIdentifier"),
            name: raw.name,
            sections: sections
        )
    }

    private static func shortcut(from raw: RawShortcut, section: String, path: String) throws -> MenuShortcut {
        let title = try text(raw.title, field: "\(path).title")
        let modifiers = try (raw.modifiers ?? []).reduce(into: ModifierMask.noCommand) { mask, name in
            guard let modifier = PackKeys.modifier(named: name) else {
                throw PackError.invalidValue(field: "\(path).modifiers", reason: "unknown modifier \"\(name)\"")
            }
            mask = modifier == .noCommand ? mask.subtracting(.noCommand) : mask.union(modifier)
        }
        guard let shortcut = PackKeys.shortcut(
            title: title, key: raw.key, modifiers: modifiers, menuPath: [section, title]
        ) else {
            throw PackError.invalidValue(field: "\(path).key", reason: "unknown key \"\(raw.key)\"")
        }
        return shortcut
    }

    private static func text(_ value: String, field: String) throws -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PackError.invalidValue(field: field, reason: "must not be empty")
        }
        return value
    }

    private static func packError(_ error: any Error) -> PackError {
        if let error = error as? PackError {
            return error
        }
        guard let error = error as? DecodingError else {
            return .invalidJSON
        }
        switch error {
        case let .keyNotFound(key, context):
            return .missingField(path(context.codingPath + [key]))
        case let .valueNotFound(_, context):
            return .missingField(path(context.codingPath))
        case let .typeMismatch(_, context) where !context.codingPath.isEmpty:
            return .invalidValue(field: path(context.codingPath), reason: "wrong type")
        default:
            // Unparsable text, or a top level that is not an object.
            return .invalidJSON
        }
    }

    /// `sections[0].shortcuts[2].key` style.
    private static func path(_ keys: [any CodingKey]) -> String {
        keys.reduce("") { path, key in
            if let index = key.intValue {
                return "\(path)[\(index)]"
            }
            return path.isEmpty ? key.stringValue : "\(path).\(key.stringValue)"
        }
    }
}
