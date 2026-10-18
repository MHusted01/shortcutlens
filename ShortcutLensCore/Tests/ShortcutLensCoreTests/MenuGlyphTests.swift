import ShortcutLensCore
import Testing

struct MenuGlyphTests {
    @Test(arguments: [
        (0x6F, "F1"), (0x70, "F2"), (0x71, "F3"), (0x72, "F4"), (0x73, "F5"),
        (0x74, "F6"), (0x75, "F7"), (0x76, "F8"), (0x77, "F9"), (0x78, "F10"),
        (0x79, "F11"), (0x7A, "F12"), (0x87, "F13"), (0x88, "F14"), (0x89, "F15"),
        (0x8F, "F16"), (0x90, "F17"), (0x91, "F18"), (0x92, "F19"),
    ])
    func mapsFunctionKeys(code: Int, symbol: String) {
        #expect(MenuGlyph.symbol(for: code) == symbol)
    }

    @Test(arguments: [
        (0x64, "←"), (0x65, "→"), (0x68, "↑"), (0x6A, "↓"),
        (0x17, "⌫"), (0x0A, "⌦"), (0x0B, "↩"), (0x04, "⌤"),
        (0x02, "⇥"), (0x1B, "⎋"), (0x09, "Space"),
        (0x62, "⇞"), (0x6B, "⇟"), (0x66, "↖"), (0x69, "↘"), (0x67, "Help"),
    ])
    func mapsNamedKeys(code: Int, symbol: String) {
        #expect(MenuGlyph.symbol(for: code) == symbol)
    }

    @Test(arguments: [0x00, 0x01, 0x11, 0x7B, 0x86, 0x93, -1, 1000])
    func unknownCodesReturnNil(code: Int) {
        #expect(MenuGlyph.symbol(for: code) == nil)
    }
}
