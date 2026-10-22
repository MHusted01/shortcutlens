/// Keys without a printable character, as AppKit reports them in key events
/// and `NSUserKeyEquivalents` stores them, mapped to the `kMenu*Glyph` code
/// that `MenuGlyph` renders.
///
/// Function keys, arrows and other keys without a control character are
/// AppKit's private-use characters (`NSF1FunctionKey` is U+F704). Some apps
/// also report Space, Return and the like as a character instead of a glyph.
enum NamedKeys {
    /// The glyph code for `character`, or nil when it is not a named key.
    static func glyph(for character: String) -> Int? {
        glyphs[character]
    }

    /// F1...F19, which an App Shortcut may use without a modifier.
    static func isFunctionKey(_ character: String) -> Bool {
        functionKeyGlyphs[character] != nil
    }

    /// Traps if a character appears twice, so the two tables cannot silently overlap.
    private static let glyphs = Dictionary(uniqueKeysWithValues: Array(otherKeyGlyphs) + Array(functionKeyGlyphs))

    /// NSF1FunctionKey...NSF19FunctionKey (U+F704...U+F716), in order.
    private static let functionKeyGlyphs: [String: Int] = {
        let characters = (0xF704 ... 0xF716).compactMap(Unicode.Scalar.init).map(String.init)
        return Dictionary(uniqueKeysWithValues: characters.enumerated().compactMap { index, character in
            MenuGlyph.code(for: "F\(index + 1)").map { (character, $0) }
        })
    }()

    private static let otherKeyGlyphs: [String: Int] = [
        " ": 0x09, // kMenuSpaceGlyph
        "\r": 0x0B, // kMenuReturnGlyph
        "\n": 0x0B, // kMenuReturnGlyph (newline)
        "\u{3}": 0x04, // kMenuEnterGlyph
        "\t": 0x02, // kMenuTabRightGlyph
        "\u{1B}": 0x1B, // kMenuEscapeGlyph
        "\u{7F}": 0x17, // kMenuDeleteLeftGlyph
        "\u{8}": 0x17, // kMenuDeleteLeftGlyph (backspace)
        "\u{F700}": 0x68, // NSUpArrowFunctionKey
        "\u{F701}": 0x6A, // NSDownArrowFunctionKey
        "\u{F702}": 0x64, // NSLeftArrowFunctionKey
        "\u{F703}": 0x65, // NSRightArrowFunctionKey
        "\u{F728}": 0x0A, // NSDeleteFunctionKey (forward delete)
        "\u{F729}": 0x66, // NSHomeFunctionKey
        "\u{F72B}": 0x69, // NSEndFunctionKey
        "\u{F72C}": 0x62, // NSPageUpFunctionKey
        "\u{F72D}": 0x6B, // NSPageDownFunctionKey
        "\u{F746}": 0x67, // NSHelpFunctionKey
    ]
}
