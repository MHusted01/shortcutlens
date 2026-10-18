/// An `AXClient` that can also press elements, for running menu items.
public protocol AXActionClient: AXClient {
    /// Performs `AXPress` on `element`; nil on success.
    func press(_ element: Element) -> AXPressError?
}

/// Why an `AXPress` failed, decoded from the `AXError` it returned.
public enum AXPressError: Error, Hashable, Sendable {
    /// The element no longer exists, e.g. the app rebuilt its menu.
    case invalidElement
    /// The app did not answer in time or the request could not be sent.
    case cannotComplete
    /// The element does not support `AXPress`.
    case actionUnsupported
    case other(code: Int32)

    /// Raw `AXError` values from `AXError.h`.
    private static let invalidElementCode: Int32 = -25202
    private static let cannotCompleteCode: Int32 = -25204
    private static let actionUnsupportedCode: Int32 = -25206

    /// Decodes a raw `AXError` value; nil for `kAXErrorSuccess` (0).
    public init?(axErrorCode code: Int32) {
        switch code {
        case 0:
            return nil
        case Self.invalidElementCode:
            self = .invalidElement
        case Self.cannotCompleteCode:
            self = .cannotComplete
        case Self.actionUnsupportedCode:
            self = .actionUnsupported
        default:
            self = .other(code: code)
        }
    }
}

/// The result of running one menu item.
public enum MenuItemRunOutcome: Hashable, Sendable {
    case pressed
    /// The item was disabled at click time, so it was not pressed.
    case disabled
    /// The item's attributes could not be read, so it was not pressed. The
    /// element is most likely stale.
    case unreadable
    case failed(AXPressError)

    /// A fixed description for local logs. It never contains menu titles or
    /// other user data.
    public var logDescription: String {
        switch self {
        case .pressed:
            "pressed"
        case .disabled:
            "disabled"
        case .unreadable:
            "unreadable"
        case .failed(.invalidElement):
            "failed: invalid element"
        case .failed(.cannotComplete):
            "failed: cannot complete"
        case .failed(.actionUnsupported):
            "failed: action unsupported"
        case let .failed(.other(code)):
            "failed: AX error \(code)"
        }
    }
}

/// Runs a menu item the overlay listed by pressing its element.
///
/// The menu was read up to a few seconds earlier, so the item is checked again
/// first: a disabled or unreadable item is not pressed.
public struct MenuItemRunner<Client: AXActionClient> {
    public let client: Client

    public init(client: Client) {
        self.client = client
    }

    /// Checks and presses `element`.
    ///
    /// Synchronous: each client call can wait up to the client's messaging
    /// timeout. Call it off the main actor.
    public func run(_ element: Client.Element) -> MenuItemRunOutcome {
        guard let attributes = client.attributes(of: element) else {
            return .unreadable
        }
        guard attributes.isEnabled else {
            return .disabled
        }
        return client.press(element).map(MenuItemRunOutcome.failed) ?? .pressed
    }
}
