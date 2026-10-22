/// Display data for virtual key codes (`kVK_*` from HIToolbox `Events.h`).
///
/// Keys without a printable character map to the `kMenu*Glyph` code that
/// `MenuGlyph` renders, so system shortcuts look like menu shortcuts.
/// Character keys map to what they type on the US (ANSI) layout; this is the
/// last fallback when neither the current layout (`KeyLabels`) nor the store
/// has a character.
enum KeyCodes {
    static func glyph(for keyCode: Int) -> Int? {
        glyphs[keyCode]
    }

    static func usCharacter(for keyCode: Int) -> Character? {
        usCharacters[keyCode]
    }

    private static let glyphs: [Int: Int] = [
        36: 0x0B, // kVK_Return
        48: 0x02, // kVK_Tab
        49: 0x09, // kVK_Space
        51: 0x17, // kVK_Delete
        53: 0x1B, // kVK_Escape
        76: 0x04, // kVK_ANSI_KeypadEnter
        114: 0x67, // kVK_Help
        115: 0x66, // kVK_Home
        116: 0x62, // kVK_PageUp
        117: 0x0A, // kVK_ForwardDelete
        119: 0x69, // kVK_End
        121: 0x6B, // kVK_PageDown
        123: 0x64, // kVK_LeftArrow
        124: 0x65, // kVK_RightArrow
        125: 0x6A, // kVK_DownArrow
        126: 0x68, // kVK_UpArrow
        // kVK_F1...kVK_F19 to kMenuF1Glyph...kMenuF19Glyph.
        122: 0x6F, 120: 0x70, 99: 0x71, 118: 0x72, 96: 0x73, 97: 0x74, 98: 0x75, 100: 0x76,
        101: 0x77, 109: 0x78, 103: 0x79, 111: 0x7A, 105: 0x87, 107: 0x88, 113: 0x89, 106: 0x8F,
        64: 0x90, 79: 0x91, 80: 0x92,
    ]

    /// kVK_ANSI_* codes. They follow the physical key layout, not the alphabet.
    private static let usCharacters: [Int: Character] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p",
        37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n",
        46: "m", 47: ".", 50: "`",
    ]
}

public extension SymbolicHotKeyBinding {
    /// The binding as a shortcut `ShortcutFormatter` can render. A non-character
    /// key's glyph wins over the stored character, which is a control code for
    /// keys such as Return. The system matches the key code, so the current
    /// layout's label for it wins over the stored character, which is from the
    /// layout the entry was saved with (US for the built-in defaults). A stored
    /// control code is ignored, so a key without a glyph still gets its
    /// US-layout label.
    func shortcut(title: String, menuPath: [String] = [], layout: KeyLabels = .none) -> MenuShortcut {
        let glyph = keyCode.flatMap(KeyCodes.glyph)
        let printable = character.flatMap { character in
            character.unicodeScalars.contains { $0.properties.generalCategory == .control } ? nil : character
        }
        let character = keyCode.flatMap(layout.label) ?? printable ?? keyCode.flatMap(KeyCodes.usCharacter)
        return MenuShortcut(
            title: title,
            keyCharacter: character.map(String.init),
            modifiers: modifiers,
            glyph: glyph,
            menuPath: menuPath
        )
    }
}
