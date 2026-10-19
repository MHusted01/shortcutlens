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
        // No prefetched keys: each file's values are read after resolving symlinks.
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: []))
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

    /// Reads at most one byte past the size limit, so a huge file is never
    /// loaded, even one that grew after it was listed; the parser rejects
    /// the oversized data. The file is opened non-blocking and checked to be
    /// a regular file on the open descriptor, so a FIFO swapped in at any
    /// moment can neither block the open nor be read.
    private static func read(file url: URL, isBundled: Bool) -> FileRead {
        let name = url.lastPathComponent
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else {
            return .failed(PackProblem(fileName: name, message: "Could not be read."))
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
            return .failed(PackProblem(fileName: name, message: "Not a readable file."))
        }
        do {
            let data = try handle.read(upToCount: ShortcutPackParser.maxFileSize + 1) ?? Data()
            return .loaded(PackFile(name: name, data: data, isBundled: isBundled))
        } catch {
            return .failed(PackProblem(fileName: name, message: "Could not be read."))
        }
    }
}
