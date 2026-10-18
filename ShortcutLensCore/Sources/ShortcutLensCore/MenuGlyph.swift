/// Display symbols for `AXMenuItemCmdGlyph` codes.
///
/// The codes are Apple's legacy HIToolbox `kMenu*Glyph` constants, which are
/// no longer shipped in current SDK headers. Only keys that appear as menu
/// shortcuts are mapped; modifier and decorative glyphs are left out.
/// Space and Help render as words because that is how macOS menus show them.
public enum MenuGlyph {
    /// The symbol for `code`, or nil when the code is not mapped.
    public static func symbol(for code: Int) -> String? {
        symbols[code]
    }

    private static let symbols: [Int: String] = {
        let functionKeys = functionKeyCodes.enumerated().map { index, code in (code, "F\(index + 1)") }
        // Traps if a code appears twice, so the two tables cannot silently overlap.
        return Dictionary(uniqueKeysWithValues: namedKeys.map { ($0.key, $0.value) } + functionKeys)
    }()

    /// kMenuF1Glyph...kMenuF19Glyph, in order. The codes are split across three blocks.
    private static let functionKeyCodes = Array(0x6F ... 0x7A) + Array(0x87 ... 0x89) + Array(0x8F ... 0x92)

    private static let namedKeys: [Int: String] = [
        0x02: "⇥", // kMenuTabRightGlyph
        0x03: "⇤", // kMenuTabLeftGlyph
        0x04: "⌤", // kMenuEnterGlyph
        0x09: "Space", // kMenuSpaceGlyph
        0x0A: "⌦", // kMenuDeleteRightGlyph
        0x0B: "↩", // kMenuReturnGlyph
        0x17: "⌫", // kMenuDeleteLeftGlyph
        0x1B: "⎋", // kMenuEscapeGlyph
        0x1C: "⌧", // kMenuClearGlyph
        0x62: "⇞", // kMenuPageUpGlyph
        0x64: "←", // kMenuLeftArrowGlyph
        0x65: "→", // kMenuRightArrowGlyph
        0x66: "↖", // kMenuNorthwestArrowGlyph (Home)
        0x67: "Help", // kMenuHelpGlyph
        0x68: "↑", // kMenuUpArrowGlyph
        0x69: "↘", // kMenuSoutheastArrowGlyph (End)
        0x6A: "↓", // kMenuDownArrowGlyph
        0x6B: "⇟", // kMenuPageDownGlyph
    ]
}
