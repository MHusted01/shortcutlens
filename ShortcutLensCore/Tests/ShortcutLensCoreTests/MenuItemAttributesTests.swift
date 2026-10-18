import Foundation
import ShortcutLensCore
import Testing

/// AX returns `CFBoolean`/`CFNumber` values, which arrive as `NSNumber`, and an
/// AXValue error for attributes an element lacks; `NSNull` stands in for that.
struct MenuItemAttributesTests {
    @Test func decodesValuesInAttributeOrder() {
        let values: [Any] = [
            "Save As…", NSNumber(value: false), "AXMenuItem", "S", NSNumber(value: 1), NSNumber(value: 0),
        ]

        let attributes = MenuItemAttributes(axValues: values)

        #expect(attributes == MenuItemAttributes(
            title: "Save As…",
            isEnabled: false,
            role: "AXMenuItem",
            keyCharacter: "S",
            modifiers: 1,
            glyph: 0
        ))
    }

    @Test func turnsMissingAttributesIntoNil() {
        let values: [Any] = Array(repeating: NSNull(), count: MenuItemAttributes.axAttributeNames.count)

        #expect(MenuItemAttributes(axValues: values) == MenuItemAttributes())
    }

    @Test func turnsWrongTypesIntoNil() {
        let values: [Any] = [NSNumber(value: 3), "yes", NSNumber(value: 4), NSNumber(value: 5), "8", "glyph"]

        let attributes = MenuItemAttributes(axValues: values)

        #expect(attributes == MenuItemAttributes())
    }

    @Test(arguments: [0, 5, 7])
    func rejectsWrongValueCount(count: Int) {
        let values: [Any] = Array(repeating: NSNull(), count: count)

        #expect(MenuItemAttributes(axValues: values) == nil)
    }

    @Test func namesTheSixMenuAttributes() {
        #expect(MenuItemAttributes.axAttributeNames == [
            "AXTitle",
            "AXEnabled",
            "AXRole",
            "AXMenuItemCmdChar",
            "AXMenuItemCmdModifiers",
            "AXMenuItemCmdGlyph",
        ])
    }
}
