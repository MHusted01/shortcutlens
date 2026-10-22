import Foundation
import ShortcutLensCore
import Testing

struct PackLibraryTests {
    private func file(_ name: String, bundleID: String, section: String, isBundled: Bool = false) -> PackFile {
        let json = """
        {"schemaVersion": 1, "bundleIdentifier": "\(bundleID)",
         "sections": [{"title": "\(section)", "shortcuts": [{"title": "Open", "key": "o"}]}]}
        """
        return PackFile(name: name, data: Data(json.utf8), isBundled: isBundled)
    }

    @Test func sectionsComeFromPacksForTheBundleID() {
        let library = PackLibrary(files: [
            file("b.json", bundleID: "com.example.app", section: "Second"),
            file("a.json", bundleID: "com.example.app", section: "First"),
            file("c.json", bundleID: "com.example.other", section: "Other"),
        ])

        #expect(library.sections(for: "com.example.app").map(\.title) == ["First", "Second"])
        #expect(library.sections(for: "com.example.none").isEmpty)
        #expect(library.sections(for: nil).isEmpty)
        #expect(library.packs.count == 3)
    }

    @Test func userPackReplacesTheBundledPackForTheSameApp() {
        let library = PackLibrary(files: [
            file("finder.json", bundleID: "com.apple.finder", section: "Bundled", isBundled: true),
            file("mine.json", bundleID: "com.apple.finder", section: "Mine"),
            file("other.json", bundleID: "com.example.app", section: "Kept", isBundled: true),
        ])

        #expect(library.sections(for: "com.apple.finder").map(\.title) == ["Mine"])
        #expect(library.sections(for: "com.example.app").map(\.title) == ["Kept"])
    }

    @Test func problemFilesAreListedByNameAndSkipped() {
        let library = PackLibrary(
            files: [
                PackFile(name: "bad.json", data: Data("{".utf8), isBundled: false),
                file("ok.json", bundleID: "com.example.app", section: "Fine"),
            ],
            unreadable: [PackProblem(fileName: "locked.json", message: "Could not be read.")]
        )

        #expect(library.sections(for: "com.example.app").map(\.title) == ["Fine"])
        #expect(library.problems == [
            PackProblem(fileName: "bad.json", message: "Not valid JSON."),
            PackProblem(fileName: "locked.json", message: "Could not be read."),
        ])
    }

    @Test func emptyLibraryHasNothing() {
        #expect(PackLibrary.empty.packs.isEmpty)
        #expect(PackLibrary.empty.problems.isEmpty)
    }
}
