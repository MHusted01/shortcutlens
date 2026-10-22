import Foundation
import ShortcutLensCore
import Testing

struct ShortcutPackParserTests {
    private func parse(_ json: String) -> Result<ShortcutPack, PackError> {
        ShortcutPackParser.parse(Data(json.utf8))
    }

    private func pack(shortcuts: String) -> String {
        """
        {"schemaVersion": 1, "bundleIdentifier": "com.example.app", "name": "Example",
         "sections": [{"title": "Navigation", "shortcuts": [\(shortcuts)]}]}
        """
    }

    private func error(_ json: String) -> PackError? {
        guard case let .failure(error) = parse(json) else {
            return nil
        }
        return error
    }

    private func keys(_ shortcuts: String) throws -> [String?] {
        let pack = try parse(pack(shortcuts: shortcuts)).get()
        return pack.sections[0].shortcuts.map { ShortcutFormatter.string(for: $0) }
    }

    @Test func parsesAValidPack() throws {
        let pack = try parse(pack(shortcuts: #"{"title": "Open", "key": "Down", "modifiers": ["command"]}"#)).get()

        #expect(pack.bundleIdentifier == "com.example.app")
        #expect(pack.name == "Example")
        #expect(pack.sections.map(\.title) == ["Navigation"])
        let shortcut = try #require(pack.sections[0].shortcuts.first)
        #expect(shortcut.title == "Open")
        #expect(shortcut.menuPath == ["Navigation", "Open"])
        #expect(ShortcutFormatter.string(for: shortcut) == "⌘↓")
    }

    @Test func nameIsOptional() throws {
        let json = #"{"schemaVersion": 1, "bundleIdentifier": "com.example.app", "sections": []}"#

        #expect(try parse(json).get().name == nil)
    }

    @Test func modifiersFollowTheMenuConvention() throws {
        let keys = try keys("""
        {"title": "A", "key": "k"},
        {"title": "B", "key": "k", "modifiers": []},
        {"title": "C", "key": "k", "modifiers": ["shift", "command", "option", "control"]},
        {"title": "D", "key": "Tab", "modifiers": ["shift"]}
        """)

        #expect(keys == ["K", "K", "⌃⌥⇧⌘K", "⇧⇥"])
    }

    @Test func namedKeysMapToTheirGlyphs() throws {
        let names = [
            "Space", "Return", "Enter", "Tab", "Escape", "Delete", "ForwardDelete", "Clear",
            "PageUp", "PageDown", "Home", "End", "Left", "Right", "Up", "Down", "Help", "F1", "F19",
        ]
        let shortcuts = names.map { #"{"title": "\#($0)", "key": "\#($0)"}"# }.joined(separator: ",")

        #expect(try keys(shortcuts) == [
            "Space", "↩", "⌤", "⇥", "⎋", "⌫", "⌦", "⌧", "⇞", "⇟", "↖", "↘", "←", "→", "↑", "↓", "Help", "F1", "F19",
        ])
    }

    /// A menu reports Space as a character and Help as a glyph.
    @Test(arguments: [
        (
            #"{"title": "Quick Look", "key": "Space"}"#,
            MenuShortcut(title: "Look", keyCharacter: " ", modifiers: .noCommand)
        ),
        (
            #"{"title": "Help", "key": "Help", "modifiers": ["shift", "command"]}"#,
            MenuShortcut(title: "Help", keyCharacter: nil, modifiers: .shift, glyph: 0x67)
        ),
    ])
    func packKeysMakeTheMenusCombo(shortcut: String, menu: MenuShortcut) throws {
        let pack = try parse(pack(shortcuts: shortcut)).get()

        #expect(KeyCombo(pack.sections[0].shortcuts[0]) == KeyCombo(menu))
    }

    @Test func badJSONIsReported() {
        #expect(error("{not json") == .invalidJSON)
        #expect(error("[]") == .invalidJSON)
    }

    @Test func unknownVersionIsReportedBeforeOtherFields() {
        #expect(error(#"{"schemaVersion": 2}"#) == .unsupportedVersion(2))
    }

    @Test func missingFieldsAreNamed() {
        let shortcut = "sections[0].shortcuts[0]"

        #expect(error(#"{"bundleIdentifier": "a", "sections": []}"#) == .missingField("schemaVersion"))
        #expect(error(#"{"schemaVersion": 1, "sections": []}"#) == .missingField("bundleIdentifier"))
        #expect(error(#"{"schemaVersion": 1, "bundleIdentifier": "a"}"#) == .missingField("sections"))
        #expect(error(#"{"schemaVersion": 1, "bundleIdentifier": "a", "sections": [{"shortcuts": []}]}"#)
            == .missingField("sections[0].title"))
        #expect(error(#"{"schemaVersion": 1, "bundleIdentifier": "a", "sections": [{"title": "X"}]}"#)
            == .missingField("sections[0].shortcuts"))
        #expect(error(pack(shortcuts: #"{"title": "Open"}"#)) == .missingField("\(shortcut).key"))
        #expect(error(pack(shortcuts: #"{"key": "a"}"#)) == .missingField("\(shortcut).title"))
        #expect(error(pack(shortcuts: #"{"title": null, "key": "a"}"#)) == .missingField("\(shortcut).title"))
    }

    @Test func repeatedModifiersCountOnce() throws {
        #expect(try keys(#"{"title": "A", "key": "k", "modifiers": ["shift", "shift", "command"]}"#) == ["⇧⌘K"])
    }

    @Test func extraFieldsAreIgnored() throws {
        #expect(try keys(#"{"title": "A", "key": "k", "note": "mine"}"#) == ["K"])
    }

    @Test func wrongTypesAreReported() {
        #expect(error(#"{"schemaVersion": "1"}"#) == .invalidValue(field: "schemaVersion", reason: .wrongType))
        #expect(
            error(#"{"schemaVersion": 1, "bundleIdentifier": "a", "sections": {}}"#)
                == .invalidValue(field: "sections", reason: .wrongType)
        )
        #expect(
            error(pack(shortcuts: #"{"title": "A", "key": 5}"#))
                == .invalidValue(field: "sections[0].shortcuts[0].key", reason: .wrongType)
        )
    }

    @Test func emptyTextIsReported() {
        let json = #"{"schemaVersion": 1, "bundleIdentifier": " ", "sections": []}"#

        #expect(error(json) == .invalidValue(field: "bundleIdentifier", reason: .empty))
        #expect(
            error(#"{"schemaVersion": 1, "bundleIdentifier": "a", "sections": [{"title": "", "shortcuts": []}]}"#)
                == .invalidValue(field: "sections[0].title", reason: .empty)
        )
        #expect(
            error(pack(shortcuts: #"{"title": "", "key": "a"}"#))
                == .invalidValue(field: "sections[0].shortcuts[0].title", reason: .empty)
        )
    }

    @Test func unknownKeysAndModifiersAreReported() {
        #expect(
            error(pack(shortcuts: #"{"title": "A", "key": "ab"}"#))
                == .invalidValue(field: "sections[0].shortcuts[0].key", reason: .unknownKey("ab"))
        )
        #expect(
            error(pack(shortcuts: #"{"title": "A", "key": "a", "modifiers": ["hyper"]}"#))
                == .invalidValue(field: "sections[0].shortcuts[0].modifiers", reason: .unknownModifier("hyper"))
        )
    }

    @Test func messagesAreReadable() {
        #expect(PackError.invalidJSON.message == "Not valid JSON.")
        #expect(PackError.unsupportedVersion(2).message == "Unsupported schemaVersion 2; this version reads 1.")
        #expect(PackError.missingField("sections").message == "Missing field \"sections\".")
        #expect(PackError.tooLarge.message == "File is larger than 256 KB.")
    }

    @Test func invalidValueMessagesNameTheReason() {
        func message(_ reason: PackError.Reason) -> String {
            PackError.invalidValue(field: "f", reason: reason).message
        }

        #expect(message(.empty) == "Invalid \"f\": must not be empty.")
        #expect(message(.wrongType) == "Invalid \"f\": wrong type.")
        #expect(message(.unknownKey("ab")) == "Invalid \"f\": unknown key \"ab\".")
        #expect(message(.unknownModifier("hyper")) == "Invalid \"f\": unknown modifier \"hyper\".")
    }

    /// A file at the limit is read; its zero bytes are not JSON.
    @Test(arguments: [
        (ShortcutPackParser.maxFileSize, PackError.invalidJSON),
        (ShortcutPackParser.maxFileSize + 1, PackError.tooLarge),
    ])
    func filesAboveTheSizeLimitAreRejectedUnread(size: Int, expected: PackError) {
        #expect(ShortcutPackParser.parse(Data(count: size)) == .failure(expected))
    }

    @Test func bundledExamplePackLoads() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repository.appending(path: "App/Resources/Packs/com.apple.finder.json")

        let pack = try ShortcutPackParser.parse(Data(contentsOf: url)).get()

        #expect(pack.bundleIdentifier == "com.apple.finder")
        #expect(!pack.sections.isEmpty)
        #expect(pack.sections.allSatisfy { !$0.shortcuts.isEmpty })
    }
}
