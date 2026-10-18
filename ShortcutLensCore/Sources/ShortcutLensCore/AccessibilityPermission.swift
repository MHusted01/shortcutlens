/// Tracks the Accessibility permission across checks and decides when the
/// onboarding window opens or closes. Onboarding opens at most once per launch;
/// the menu bar item can reopen it on request.
public struct AccessibilityPermission: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        /// Not checked yet.
        case unknown
        case missing
        case granted
    }

    /// What the app should do after a check.
    public enum Action: Equatable, Sendable {
        case none
        case showOnboarding
        case closeOnboarding
    }

    public static let initial = Self(status: .unknown, hasShownOnboarding: false)

    public let status: Status
    /// Whether onboarding has opened automatically during this launch.
    public let hasShownOnboarding: Bool

    public var isGranted: Bool {
        status == .granted
    }

    /// The state after a check that found the process trusted or not, and the
    /// action that check calls for.
    public func updated(isTrusted: Bool) -> (state: Self, action: Action) {
        if isTrusted {
            let action: Action = status == .missing ? .closeOnboarding : .none
            return (Self(status: .granted, hasShownOnboarding: hasShownOnboarding), action)
        }
        let action: Action = hasShownOnboarding ? .none : .showOnboarding
        return (Self(status: .missing, hasShownOnboarding: true), action)
    }
}
