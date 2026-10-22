import Foundation
import ShortcutLensCore
import Testing

struct SymbolicHotKeyParserTests {
    /// The `AppleSymbolicHotKeys` dictionary of a fixture plist, read the way
    /// `CFPreferences` hands it to the app (Foundation objects).
    static func fixture(_ name: String) throws -> [String: Any] {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "plist", subdirectory: "Fixtures"))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let root = try #require(plist as? [String: Any])
        return try #require(root["AppleSymbolicHotKeys"] as? [String: Any])
    }

    @Test func parsesEnabledEntriesWithTheirKeys() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-basic"))

        #expect(hotKeys.keys.sorted() == [28, 36, 64, 79])
        #expect(hotKeys[28] == SymbolicHotKey(
            isEnabled: true,
            binding: SymbolicHotKeyBinding(character: "3", keyCode: 20, modifiers: .shift)
        ))
    }

    @Test func characterParameter65535MeansNoCharacter() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-basic"))

        #expect(hotKeys[64]?.binding == SymbolicHotKeyBinding(character: nil, keyCode: 49, modifiers: []))
    }

    @Test func eventFlagsWithoutCommandMeanNoCommand() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-basic"))

        #expect(hotKeys[36]?.binding?.modifiers == .noCommand)
        // Control plus the function-key flag macOS sets for arrow keys.
        #expect(hotKeys[79]?.binding?.modifiers == [.control, .noCommand])
    }

    @Test func keepsDisabledEntries() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-edge"))

        #expect(hotKeys[27]?.isEnabled == false)
        #expect(hotKeys[27]?.binding?.keyCode == 50)
    }

    @Test func entryWithoutValueHasNoBinding() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-edge"))

        #expect(hotKeys[32] == SymbolicHotKey(isEnabled: false, binding: nil))
    }

    @Test func malformedParametersGiveNoBinding() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-edge"))

        // A string where the character code belongs; `enabled` as an integer.
        #expect(hotKeys[52] == SymbolicHotKey(isEnabled: true, binding: nil))
        // Only two parameters; `enabled` is missing too.
        #expect(hotKeys[65] == SymbolicHotKey(isEnabled: nil, binding: nil))
    }

    @Test func keyCode65535MeansNoKey() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-edge"))

        #expect(hotKeys[160]?.binding == SymbolicHotKeyBinding(character: nil, keyCode: nil, modifiers: .noCommand))
    }

    @Test func skipsNonNumericIDsAndNonDictionaryEntries() throws {
        let hotKeys = try SymbolicHotKeyParser.parse(Self.fixture("symbolichotkeys-edge"))

        #expect(hotKeys.keys.sorted() == [27, 32, 52, 65, 160, 99999])
    }

    @Test func acceptsSwiftValuesToo() {
        let hotKeys = SymbolicHotKeyParser.parse([
            "64": ["enabled": 1, "value": ["parameters": [32, 49, 0x100000]]],
        ])

        #expect(hotKeys[64] == SymbolicHotKey(
            isEnabled: true,
            binding: SymbolicHotKeyBinding(character: " ", keyCode: 49, modifiers: [])
        ))
    }

    @Test func invalidCharacterCodeIsDropped() {
        let surrogate = 0xD800
        let hotKeys = SymbolicHotKeyParser.parse([
            "1": ["enabled": true, "value": ["parameters": [surrogate, 0, 0]]],
        ])

        #expect(hotKeys[1]?.binding?.character == nil)
        #expect(hotKeys[1]?.binding?.keyCode == 0)
    }

    /// "7" and "07" name the same ID; which entry wins is not defined.
    @Test func idsWithTheSameNumberKeepOneEntry() {
        let hotKeys = SymbolicHotKeyParser.parse([
            "7": ["enabled": true],
            "07": ["enabled": false],
        ])

        #expect(hotKeys.count == 1)
        #expect(hotKeys[7]?.isEnabled != nil)
    }

    @Test func emptyDictionaryGivesNothing() {
        #expect(SymbolicHotKeyParser.parse([:]).isEmpty)
    }
}
