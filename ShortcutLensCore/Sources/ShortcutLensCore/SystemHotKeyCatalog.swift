/// A system shortcut ShortcutLens knows by ID, with the built-in default the
/// system uses while `com.apple.symbolichotkeys` has no entry for it.
public struct SystemHotKeyDefinition: Sendable {
    public let id: Int
    /// The name System Settings shows.
    public let title: String
    public let isEnabledByDefault: Bool
    /// Nil for shortcuts that have no keys until the user assigns some.
    public let defaultBinding: SymbolicHotKeyBinding?
}

/// The system shortcuts the overlay lists, merged from the store and the
/// built-in defaults. IDs that are not in the catalog are not shown, because
/// the store has no names and many IDs are obsolete or hidden.
public enum SystemHotKeyCatalog {
    /// The section and menu path name for system shortcuts.
    public static let sectionTitle = "System"

    /// Enabled shortcuts that have a displayable key, in catalog order. A
    /// store entry's flag and keys win over the defaults; a missing flag or
    /// malformed keys fall back to them.
    public static func shortcuts(from hotKeys: [Int: SymbolicHotKey]) -> [MenuShortcut] {
        definitions.compactMap { definition in
            let entry = hotKeys[definition.id]
            guard entry?.isEnabled ?? definition.isEnabledByDefault,
                  let binding = entry?.binding ?? definition.defaultBinding
            else {
                return nil
            }
            let shortcut = binding.shortcut(title: definition.title, menuPath: [sectionTitle, definition.title])
            return ShortcutFormatter.keySymbol(for: shortcut) == nil ? nil : shortcut
        }
    }

    private static let shift = EventFlag.shift
    private static let control = EventFlag.control
    private static let option = EventFlag.option
    private static let command = EventFlag.command

    private static func entry(
        _ id: Int, _ title: String, _ character: Character?, _ keyCode: Int, _ flags: Int, enabled: Bool = true
    ) -> SystemHotKeyDefinition {
        let binding = SymbolicHotKeyBinding(
            character: character, keyCode: keyCode, modifiers: ModifierMask(eventFlags: flags)
        )
        return SystemHotKeyDefinition(id: id, title: title, isEnabledByDefault: enabled, defaultBinding: binding)
    }

    private static func unassigned(_ id: Int, _ title: String) -> SystemHotKeyDefinition {
        SystemHotKeyDefinition(id: id, title: title, isEnabledByDefault: false, defaultBinding: nil)
    }

    /// Grouped like System Settings > Keyboard Shortcuts.
    public static let definitions: [SystemHotKeyDefinition] = spotlight + screenshots + missionControl
        + desktops + keyboard + inputSources + accessibility + unassignedByDefault

    private static let spotlight = [
        entry(64, "Show Spotlight search", " ", 49, command),
        entry(65, "Show Finder search window", " ", 49, option | command),
    ]

    private static let screenshots = [
        entry(28, "Save picture of screen as a file", "3", 20, shift | command),
        entry(29, "Copy picture of screen to the clipboard", "3", 20, control | shift | command),
        entry(30, "Save picture of selected area as a file", "4", 21, shift | command),
        entry(31, "Copy picture of selected area to the clipboard", "4", 21, control | shift | command),
        entry(184, "Screenshot and recording options", "5", 23, shift | command),
    ]

    private static let missionControl = [
        entry(32, "Mission Control", nil, 126, control),
        entry(33, "Application windows", nil, 125, control),
        entry(36, "Show Desktop", nil, 103, 0),
        entry(79, "Move left a space", nil, 123, control),
        entry(81, "Move right a space", nil, 124, control),
    ]

    /// "Switch to Desktop n" is off until the user turns it on.
    private static let desktops: [SystemHotKeyDefinition] = {
        let keyCodes = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        return keyCodes.enumerated().map { index, keyCode in
            let number = index + 1
            return entry(117 + number, "Switch to Desktop \(number)", nil, keyCode, control, enabled: false)
        }
    }()

    private static let keyboard = [
        entry(12, "Turn keyboard access on or off", nil, 122, control),
        entry(7, "Move focus to the menu bar", nil, 120, control),
        entry(8, "Move focus to the Dock", nil, 99, control),
        entry(9, "Move focus to active or next window", nil, 118, control),
        entry(10, "Move focus to window toolbar", nil, 96, control),
        entry(11, "Move focus to floating window", nil, 97, control),
        entry(27, "Move focus to next window", "`", 50, command),
        entry(13, "Change the way Tab moves focus", nil, 98, control),
        entry(57, "Move focus to status menus", nil, 100, control),
        entry(52, "Turn Dock hiding on or off", "d", 2, option | command),
        entry(98, "Show Help menu", "/", 44, shift | command),
    ]

    private static let inputSources = [
        entry(60, "Select the previous input source", " ", 49, control),
        entry(61, "Select next source in Input menu", " ", 49, control | option),
    ]

    private static let accessibility = [
        entry(15, "Turn zoom on or off", "8", 28, option | command, enabled: false),
        entry(17, "Zoom in", "=", 24, option | command, enabled: false),
        entry(19, "Zoom out", "-", 27, option | command, enabled: false),
        entry(21, "Invert colours", "8", 28, control | option | command, enabled: false),
        entry(59, "Turn VoiceOver on or off", nil, 96, command),
        entry(162, "Show Accessibility controls", nil, 96, option | command),
    ]

    private static let unassignedByDefault = [
        unassigned(160, "Show Launchpad"),
        unassigned(163, "Show Notification Center"),
        unassigned(175, "Turn Do Not Disturb on or off"),
    ]
}
