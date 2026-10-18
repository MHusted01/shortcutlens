/// One entry of `com.apple.symbolichotkeys`, the store behind the shortcuts in
/// System Settings > Keyboard > Keyboard Shortcuts.
///
/// The store only holds entries the system or the user has written, so a field
/// that is missing here means "use the built-in default", see
/// `SystemHotKeyCatalog`.
public struct SymbolicHotKey: Equatable, Sendable {
    /// The `enabled` flag, nil when the entry has none.
    public let isEnabled: Bool?
    /// The keys from `value.parameters`, nil when missing or malformed.
    public let binding: SymbolicHotKeyBinding?

    public init(isEnabled: Bool?, binding: SymbolicHotKeyBinding?) {
        self.isEnabled = isEnabled
        self.binding = binding
    }
}

/// The keys of a symbolic hotkey: `parameters` is `[character, keyCode, flags]`.
public struct SymbolicHotKeyBinding: Hashable, Sendable {
    /// The value both the character and the key code use for "none".
    public static let none = 65535

    /// The character the key types on the layout the entry was saved with,
    /// nil when the store has none.
    public let character: Character?
    /// The virtual key code (`kVK_*`), nil when the shortcut has no key.
    public let keyCode: Int?
    public let modifiers: ModifierMask

    public init(character: Character?, keyCode: Int?, modifiers: ModifierMask) {
        self.character = character
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Decodes `[character, keyCode, flags]`; nil unless there are three integers.
    public init?(parameters: [Int]) {
        guard parameters.count == 3 else {
            return nil
        }
        let (character, keyCode, flags) = (parameters[0], parameters[1], parameters[2])
        self.init(
            character: character == Self.none ? nil : Unicode.Scalar(character).map(Character.init),
            keyCode: keyCode == Self.none ? nil : keyCode,
            modifiers: ModifierMask(eventFlags: flags)
        )
    }
}

public extension ModifierMask {
    /// `NSEvent.ModifierFlags` raw values as the store keeps them.
    private enum EventFlag {
        static let shift = 0x20000
        static let control = 0x40000
        static let option = 0x80000
        static let command = 0x100000
    }

    /// Decodes `NSEvent.ModifierFlags` bits. Other bits, such as the
    /// function-key flag macOS adds for arrow keys, are ignored.
    init(eventFlags: Int) {
        let pairs: [(flag: Int, modifier: ModifierMask)] = [
            (EventFlag.shift, .shift),
            (EventFlag.option, .option),
            (EventFlag.control, .control),
        ]
        let base: ModifierMask = eventFlags & EventFlag.command == 0 ? .noCommand : []
        self = pairs
            .filter { eventFlags & $0.flag != 0 }
            .reduce(base) { $0.union($1.modifier) }
    }
}

/// Reads the `AppleSymbolicHotKeys` dictionary.
///
/// The input is untrusted: entries whose ID is not a number or that are not
/// dictionaries are skipped, and malformed fields become nil, never a crash.
public enum SymbolicHotKeyParser {
    public static func parse(_ dictionary: [String: Any]) -> [Int: SymbolicHotKey] {
        let pairs = dictionary.compactMap { key, value -> (Int, SymbolicHotKey)? in
            guard let id = Int(key), let entry = value as? [String: Any] else {
                return nil
            }
            return (id, SymbolicHotKey(isEnabled: flag(entry["enabled"]), binding: binding(entry["value"])))
        }
        // Keys are unique strings, but "7" and "07" name the same ID; keep either.
        return Dictionary(pairs) { first, _ in first }
    }

    /// Plists store the flag as a boolean, older ones as 0 or 1.
    private static func flag(_ value: Any?) -> Bool? {
        (value as? Bool) ?? (value as? Int).map { $0 != 0 }
    }

    private static func binding(_ value: Any?) -> SymbolicHotKeyBinding? {
        guard let value = value as? [String: Any], let parameters = value["parameters"] as? [Any] else {
            return nil
        }
        let numbers = parameters.compactMap { $0 as? Int }
        guard numbers.count == parameters.count else {
            return nil
        }
        return SymbolicHotKeyBinding(parameters: numbers)
    }
}
