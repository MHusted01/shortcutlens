import Foundation
import ShortcutLensCore
import Testing

struct SandboxContainerTests {
    private let home = URL(filePath: "/Users/test", directoryHint: .isDirectory)

    @Test func buildsThePreferencesFileInsideTheContainer() throws {
        let url = try #require(SandboxContainer.preferencesFile(bundleID: "com.apple.TextEdit", home: home))

        let container = "/Users/test/Library/Containers/com.apple.TextEdit"
        #expect(url.path == container + "/Data/Library/Preferences/com.apple.TextEdit.plist")
    }

    @Test(arguments: ["", ".", "..", "../com.apple.TextEdit", "com/apple", "com.apple..x", ".hidden", "com apple"])
    func rejectsBundleIDsThatAreNotPlainIdentifiers(bundleID: String) {
        #expect(SandboxContainer.preferencesFile(bundleID: bundleID, home: home) == nil)
    }

    @Test func rejectsOverlongBundleIDs() {
        let bundleID = String(repeating: "a", count: SandboxContainer.maxBundleIDLength + 1)

        #expect(SandboxContainer.preferencesFile(bundleID: bundleID, home: home) == nil)
    }

    @Test func acceptsHyphensAndUnderscores() {
        #expect(SandboxContainer.preferencesFile(bundleID: "dev.some-app_2", home: home) != nil)
    }

    @Test func readsTheAppShortcutsFromPlistData() throws {
        let data = try plist(["NSUserKeyEquivalents": ["Show Fonts": "@$t", "Other": 3], "Unrelated": true])

        let entries = try #require(SandboxContainer.equivalents(fromPreferences: data))

        #expect(entries.map(\.title) == ["Show Fonts"])
        #expect(entries.map(\.key) == ["t"])
    }

    @Test func readsNoEntriesWhenTheKeyIsMissing() throws {
        let data = try plist(["Unrelated": true])

        #expect(SandboxContainer.equivalents(fromPreferences: data) == [])
    }

    @Test func readsNoEntriesWhenTheKeyHasTheWrongType() throws {
        let data = try plist(["NSUserKeyEquivalents": "@t"])

        #expect(SandboxContainer.equivalents(fromPreferences: data) == [])
    }

    @Test func rejectsDataThatIsNotAPropertyListDictionary() throws {
        #expect(SandboxContainer.equivalents(fromPreferences: Data("not a plist".utf8)) == nil)
        #expect(try SandboxContainer.equivalents(fromPreferences: plist(["a", "b"])) == nil)
    }

    @Test func rejectsOversizedData() {
        let data = Data(count: SandboxContainer.maxPreferencesSize + 1)

        #expect(SandboxContainer.equivalents(fromPreferences: data) == nil)
    }

    private func plist(_ value: Any) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }
}
