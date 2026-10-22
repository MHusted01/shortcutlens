import Foundation

/// Files of the repository checkout that tests read, such as the string
/// catalogs, `PRIVACY.md` and the bundled packs. Found from this file's
/// location, so a test reads them the same way from any test folder.
enum RepositoryFiles {
    /// The repository root: the nearest folder above this file that holds
    /// `project.yml`.
    static let root = root(above: URL(fileURLWithPath: #filePath).deletingLastPathComponent())

    private static func root(above folder: URL) -> URL {
        if FileManager.default.fileExists(atPath: folder.appending(path: "project.yml").path(percentEncoded: false)) {
            return folder
        }
        let parent = folder.deletingLastPathComponent()
        precondition(parent != folder, "No project.yml above \(#filePath)")
        return root(above: parent)
    }

    /// The file or folder at `path`, relative to the repository root.
    static func url(_ path: String) -> URL {
        root.appending(path: path)
    }

    /// The Swift files in the folder at `path` and all its subfolders, sorted.
    static func swiftFiles(in path: String) -> [URL] {
        let files = FileManager.default.enumerator(at: url(path), includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        return files.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    }
}
