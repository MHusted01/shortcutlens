import ShortcutLensCore
import Testing

struct MenuItemRunnerTests {
    /// A client with one enabled "Save" item; returns the client and the item.
    private func makeClient() -> (FakeAXClient, Int) {
        let client = FakeAXClient()
        let file = client.addTopLevelMenu("File")
        let save = client.addItem("Save", key: "S", to: file)
        return (client, save)
    }

    @Test func pressesAnEnabledItem() {
        let (client, save) = makeClient()

        let outcome = MenuItemRunner(client: client).run(save)

        #expect(outcome == .pressed)
        #expect(client.presses == [save])
    }

    @Test func doesNotPressAnItemThatBecameDisabled() {
        let (client, save) = makeClient()
        client.setAttributes(MenuItemAttributes(title: "Save", isEnabled: false, role: "AXMenuItem"), of: save)

        let outcome = MenuItemRunner(client: client).run(save)

        #expect(outcome == .disabled)
        #expect(client.presses.isEmpty)
    }

    @Test func doesNotPressAnItemWhoseAttributesCannotBeRead() {
        let (client, save) = makeClient()
        client.setAttributes(nil, of: save)

        let outcome = MenuItemRunner(client: client).run(save)

        #expect(outcome == .unreadable)
        #expect(client.presses.isEmpty)
    }

    @Test(arguments: [
        AXPressError.invalidElement,
        .cannotComplete,
        .actionUnsupported,
        .other(code: -25200),
    ])
    func reportsPressErrors(error: AXPressError) {
        let (client, save) = makeClient()
        client.pressErrors[save] = error

        let outcome = MenuItemRunner(client: client).run(save)

        #expect(outcome == .failed(error))
        #expect(client.presses == [save])
    }

    @Test func mapsAXErrorCodes() {
        #expect(AXPressError(axErrorCode: 0) == nil)
        #expect(AXPressError(axErrorCode: -25202) == .invalidElement)
        #expect(AXPressError(axErrorCode: -25204) == .cannotComplete)
        #expect(AXPressError(axErrorCode: -25206) == .actionUnsupported)
        #expect(AXPressError(axErrorCode: -25211) == .other(code: -25211))
    }

    @Test func describesOutcomesWithoutUserData() {
        #expect(MenuItemRunOutcome.pressed.logDescription == "pressed")
        #expect(MenuItemRunOutcome.disabled.logDescription == "disabled")
        #expect(MenuItemRunOutcome.unreadable.logDescription == "unreadable")
        #expect(MenuItemRunOutcome.failed(.invalidElement).logDescription == "failed: invalid element")
        #expect(MenuItemRunOutcome.failed(.cannotComplete).logDescription == "failed: cannot complete")
        #expect(MenuItemRunOutcome.failed(.actionUnsupported).logDescription == "failed: action unsupported")
        #expect(MenuItemRunOutcome.failed(.other(code: -25200)).logDescription == "failed: AX error -25200")
    }
}
