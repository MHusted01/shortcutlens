/// The accessibility calls `MenuReader` needs, so the walk can be tested
/// against an in-memory tree. The app implements it with the AX API.
public protocol AXClient {
    /// An accessibility element. Hashable so a walk can detect cycles.
    associatedtype Element: Hashable

    /// The `AXMenuBar` of the process, or nil when it has none or cannot be read.
    func menuBar(forProcess pid: Int32) -> Element?

    /// `AXChildren` of `element`; empty when it has none or cannot be read.
    func children(of element: Element) -> [Element]

    /// The menu attributes of `element`, read in one call; nil when it cannot be read.
    func attributes(of element: Element) -> MenuItemAttributes?
}

/// The attributes read from one menu element. Missing attributes are nil.
public struct MenuItemAttributes: Hashable, Sendable {
    /// The AX attribute names, in the order `init(axValues:)` expects their values.
    public static let axAttributeNames = [
        "AXTitle",
        "AXEnabled",
        "AXRole",
        "AXMenuItemCmdChar",
        "AXMenuItemCmdModifiers",
        "AXMenuItemCmdGlyph",
    ]

    /// `AXTitle`.
    public let title: String?
    /// `AXEnabled`; elements that do not report it count as enabled.
    public let isEnabled: Bool
    /// `AXRole`, e.g. `AXMenuBarItem`, `AXMenu` or `AXMenuItem`.
    public let role: String?
    /// `AXMenuItemCmdChar`.
    public let keyCharacter: String?
    /// Raw `AXMenuItemCmdModifiers`. See `ModifierMask`.
    public let modifiers: Int?
    /// `AXMenuItemCmdGlyph`. See `MenuGlyph`.
    public let glyph: Int?

    public init(
        title: String? = nil,
        isEnabled: Bool = true,
        role: String? = nil,
        keyCharacter: String? = nil,
        modifiers: Int? = nil,
        glyph: Int? = nil
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.role = role
        self.keyCharacter = keyCharacter
        self.modifiers = modifiers
        self.glyph = glyph
    }

    /// Decodes the values of one multiple-attribute read, in `axAttributeNames`
    /// order. A value of the wrong type, such as the AXValue error an element
    /// returns for an attribute it lacks, becomes nil. Returns nil when the
    /// number of values does not match.
    public init?(axValues values: [Any]) {
        guard values.count == Self.axAttributeNames.count else {
            return nil
        }
        self.init(
            title: values[0] as? String,
            isEnabled: values[1] as? Bool ?? true,
            role: values[2] as? String,
            keyCharacter: values[3] as? String,
            modifiers: values[4] as? Int,
            glyph: values[5] as? Int
        )
    }
}
