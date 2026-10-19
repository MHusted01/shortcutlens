import Foundation

/// The steps of the onboarding window, in order. The window always shows one
/// of them; see the onboarding spec on #90.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    /// The app icon, the app name and what the app does.
    case welcome
    /// Hold Command for the overlay, press it twice for the palette.
    case howToUse
    /// Why the Accessibility permission is needed, and its status.
    case accessibility

    /// The default button of the footer.
    public enum PrimaryButton: Equatable, Sendable {
        case `continue`
        case openSettings
        case done

        public var title: String {
            switch self {
            case .continue: String(localized: "Continue", bundle: .module)
            case .openSettings: String(localized: "Open System Settings", bundle: .module)
            case .done: String(localized: "Done", bundle: .module)
            }
        }
    }

    /// The position shown to the user, starting at 1.
    public var number: Int {
        rawValue + 1
    }

    public var next: Self? {
        Self(rawValue: rawValue + 1)
    }

    public var previous: Self? {
        Self(rawValue: rawValue - 1)
    }

    /// Back shows from the second step on.
    public var showsBack: Bool {
        previous != nil
    }

    /// Continue until the last step; there, open System Settings until the
    /// permission is granted, then Done.
    public func primaryButton(isGranted: Bool) -> PrimaryButton {
        guard self == .accessibility else {
            return .continue
        }
        return isGranted ? .done : .openSettings
    }

    /// "Step N of 3", read by VoiceOver in place of page dots.
    public var counter: String {
        let count = Self.allCases.count
        return String(localized: "Step \(number) of \(count)", bundle: .module)
    }

    public var title: String {
        switch self {
        case .welcome: String(localized: "Welcome to ShortcutLens", bundle: .module)
        case .howToUse: String(localized: "How to use it", bundle: .module)
        case .accessibility: OnboardingText.title
        }
    }
}
