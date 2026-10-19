import Foundation
import ShortcutLensCore

/// Reads the shortcut packs: the user's from
/// `~/Library/Application Support/ShortcutLens/Packs` and the examples
/// bundled in the app.
///
/// Local files only; nothing leaves the machine. Files are read fresh on
/// every call, so an edited pack shows up on the next overlay. A missing
/// folder means no user packs, not an error.
enum PackSource {
    private static let fileExtension = "json"

    /// The folder for the user's packs.
    static var userDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "ShortcutLens/Packs", directoryHint: .isDirectory)
    }

    /// All packs and the files that were not loaded.
    static func library() -> PackLibrary {
        let bundled = Bundle.main.url(forResource: "Packs", withExtension: nil).map { read($0, isBundled: true) }
        let user = read(userDirectory, isBundled: false)
        let all = [bundled, user].compactMap(\.self)
        return PackLibrary(files: all.flatMap(\.files), unreadable: all.flatMap(\.problems))
    }

    static func createUserDirectory() throws {
        try FileManager.default.createDirectory(at: userDirectory, withIntermediateDirectories: true)
    }

    private static func read(_ directory: URL, isBundled: Bool) -> (files: [PackFile], problems: [PackProblem]) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys))
            ?? []
        let results = urls
            .filter { $0.pathExtension.lowercased() == fileExtension }
            .map { read(file: $0, isBundled: isBundled) }
        return (results.compactMap(\.file), results.compactMap(\.problem))
    }

    /// One file's outcome.
    private enum FileRead {
        case loaded(PackFile)
        case failed(PackProblem)

        var file: PackFile? {
            if case let .loaded(file) = self {
                file
            } else {
                nil
            }
        }

        var problem: PackProblem? {
            if case let .failed(problem) = self {
                problem
            } else {
                nil
            }
        }
    }

    /// Checks the size before reading, so a huge file is never loaded.
    private static func read(file url: URL, isBundled: Bool) -> FileRead {
        let name = url.lastPathComponent
        let resolved = url.resolvingSymlinksInPath()
        guard let values = try? resolved.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true
        else {
            return .failed(PackProblem(fileName: name, message: "Not a readable file."))
        }
        guard (values.fileSize ?? 0) <= ShortcutPackParser.maxFileSize else {
            return .failed(PackProblem(fileName: name, message: PackError.tooLarge.message))
        }
        guard let data = try? Data(contentsOf: resolved) else {
            return .failed(PackProblem(fileName: name, message: "Could not be read."))
        }
        return .loaded(PackFile(name: name, data: data, isBundled: isBundled))
    }
}
