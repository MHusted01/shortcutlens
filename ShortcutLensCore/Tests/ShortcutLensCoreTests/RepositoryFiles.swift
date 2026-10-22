import Foundation

/// Files of the repository checkout that tests read, such as the string
/// catalogs, `PRIVACY.md` and the bundled packs. Found from this file's
/// location, so a test reads them the same way from any test folder.
enum RepositoryFiles {
    struct NotFound: Error, CustomStringConvertible {
        let description: String
    }

    /// The repository root: the nearest folder above this file that holds
    /// `project.yml`. Throws when there is none, so only the tests that read
    /// repository files fail.
    static func root() throws -> URL {
        try root(above: URL(fileURLWithPath: #filePath).deletingLastPathComponent())
    }

    private static func root(above folder: URL) throws -> URL {
        if FileManager.default.fileExists(atPath: folder.appending(path: "project.yml").path(percentEncoded: false)) {
            return folder
        }
        let parent = folder.deletingLastPathComponent()
        guard parent != folder else {
            throw NotFound(description: "No project.yml above \(#filePath)")
        }
        return try root(above: parent)
    }

    /// The file or folder at `path`, relative to the repository root.
    static func url(_ path: String) throws -> URL {
        try root().appending(path: path)
    }

    /// The Swift files in the folder at `path` and all its subfolders, sorted.
    /// Throws when the folder cannot be read.
    static func swiftFiles(in path: String) throws -> [URL] {
        let folder = try url(path)
        return try FileManager.default.subpathsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { folder.appending(path: $0) }
    }
}
