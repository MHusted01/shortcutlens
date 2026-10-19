import Foundation

/// The contents of one pack file, read by the app.
public struct PackFile: Sendable {
    public let name: String
    public let data: Data
    /// True for packs shipped inside the app.
    public let isBundled: Bool

    public init(name: String, data: Data, isBundled: Bool) {
        self.name = name
        self.data = data
        self.isBundled = isBundled
    }
}

/// A file that was not loaded, for the Settings window.
public struct PackProblem: Hashable, Sendable {
    public let fileName: String
    public let message: String

    public init(fileName: String, message: String) {
        self.fileName = fileName
        self.message = message
    }
}

/// All pack files, parsed. A user pack for an app replaces the bundled pack
/// for that app; several user packs for one app are all used, in file name
/// order.
public struct PackLibrary: Sendable {
    public static let empty = Self(files: [])

    /// The packs in effect, in file name order.
    public let packs: [ShortcutPack]
    /// Files that were not loaded, by file name.
    public let problems: [PackProblem]

    /// `unreadable` lists files the app could not read at all.
    public init(files: [PackFile], unreadable: [PackProblem] = []) {
        let parsed = files
            .sorted { $0.name < $1.name }
            .map { (file: $0, result: ShortcutPackParser.parse($0.data)) }
        let loaded = parsed.compactMap { item in
            (try? item.result.get()).map { (pack: $0, isBundled: item.file.isBundled) }
        }
        let userApps = Set(loaded.filter { !$0.isBundled }.map(\.pack.bundleIdentifier))
        packs = loaded
            .filter { !$0.isBundled || !userApps.contains($0.pack.bundleIdentifier) }
            .map(\.pack)
        let failed = parsed.compactMap { item -> PackProblem? in
            guard case let .failure(error) = item.result else {
                return nil
            }
            return PackProblem(fileName: item.file.name, message: error.message)
        }
        problems = (unreadable + failed).sorted { $0.fileName < $1.fileName }
    }

    /// The sections for one app; empty without a bundle identifier.
    public func sections(for bundleIdentifier: String?) -> [PackSection] {
        guard let bundleIdentifier else {
            return []
        }
        return packs.filter { $0.bundleIdentifier == bundleIdentifier }.flatMap(\.sections)
    }
}
