import ApplicationServices
import ShortcutLensCore

/// `AXClient` backed by the macOS Accessibility API.
///
/// CF ownership: the `Copy*` functions return their values at +1. Swift imports
/// those out-parameters as managed references (`CFTypeRef?`, `CFArray?`), so
/// ARC releases them exactly once when they go out of scope. Nothing here calls
/// `CFRelease`, and bridging to Swift types (`as? String`, `as? [AXUIElement]`)
/// retains what it keeps. Adding a manual release would over-release.
struct SystemAXClient: AXClient {
    /// Seconds an app may take to answer one AX request before it fails, so a
    /// hung app cannot stall the overlay. The system default is about 6 seconds.
    static let defaultMessagingTimeout: Float = 0.25

    /// Order matters: `attributes(of:)` reads the values by index.
    private static let attributeNames: [String] = [
        kAXTitleAttribute,
        kAXEnabledAttribute,
        kAXRoleAttribute,
        kAXMenuItemCmdCharAttribute,
        kAXMenuItemCmdModifiersAttribute,
        kAXMenuItemCmdGlyphAttribute,
    ]

    let messagingTimeout: Float

    init(messagingTimeout: Float = Self.defaultMessagingTimeout) {
        self.messagingTimeout = messagingTimeout
    }

    func menuBar(forProcess pid: Int32) -> AXUIElement? {
        let application = withTimeout(AXUIElementCreateApplication(pid))
        return copyValue(of: kAXMenuBarAttribute, from: application)
            .flatMap(element(from:))
            .map(withTimeout)
    }

    func children(of element: AXUIElement) -> [AXUIElement] {
        let children = copyValue(of: kAXChildrenAttribute, from: element) as? [AXUIElement] ?? []
        return children.map(withTimeout)
    }

    func attributes(of element: AXUIElement) -> MenuItemAttributes? {
        var values: CFArray?
        let result = AXUIElementCopyMultipleAttributeValues(
            element,
            Self.attributeNames as CFArray,
            AXCopyMultipleAttributeOptions(),
            &values
        )
        // Attributes an element lacks come back as AXValue errors; the casts below turn them into nil.
        guard result == .success, let values = values as? [Any], values.count == Self.attributeNames.count else {
            return nil
        }
        return MenuItemAttributes(
            title: values[0] as? String,
            isEnabled: values[1] as? Bool ?? true,
            role: values[2] as? String,
            keyCharacter: values[3] as? String,
            modifiers: values[4] as? Int,
            glyph: values[5] as? Int
        )
    }

    /// The timeout only applies to the element it is set on, not to the app or
    /// to children, so every element handed out gets it. This is a local call.
    private func withTimeout(_ element: AXUIElement) -> AXUIElement {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    private func copyValue(of attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func element(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}
