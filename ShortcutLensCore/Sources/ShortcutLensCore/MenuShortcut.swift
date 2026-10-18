/// A menu item that has a keyboard shortcut, as read from the menu bar.
public struct MenuShortcut: Equatable, Sendable {
    public let title: String
    /// `AXMenuItemCmdChar`, if present.
    public let keyCharacter: String?
    public let modifiers: ModifierMask
    /// `AXMenuItemCmdGlyph`, if present. See `MenuGlyph`.
    public let glyph: Int?
    public let isEnabled: Bool
    /// Titles from the top-level menu down to this item, e.g. `["File", "Save"]`.
    public let menuPath: [String]

    public init(
        title: String,
        keyCharacter: String?,
        modifiers: ModifierMask,
        glyph: Int? = nil,
        isEnabled: Bool = true,
        menuPath: [String] = []
    ) {
        self.title = title
        self.keyCharacter = keyCharacter
        self.modifiers = modifiers
        self.glyph = glyph
        self.isEnabled = isEnabled
        self.menuPath = menuPath
    }
}
