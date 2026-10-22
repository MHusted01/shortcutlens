/// A menu item that has a keyboard shortcut, as read from the menu bar.
public struct MenuShortcut: Hashable, Sendable {
    /// The menu item's title (`AXTitle`).
    public let title: String
    /// `AXMenuItemCmdChar`, if present.
    public let keyCharacter: String?
    /// Decoded `AXMenuItemCmdModifiers`.
    public let modifiers: ModifierMask
    /// `AXMenuItemCmdGlyph`, if present. See `MenuGlyph`.
    public let glyph: Int?
    /// Whether the menu item can currently be chosen (`AXEnabled`).
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
