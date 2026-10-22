import Foundation

/// User-facing text of the onboarding. `explanation` and `noData` are quoted
/// from PRIVACY.md; a unit test keeps them in sync. Step and button titles are
/// on `OnboardingStep`.
public enum OnboardingText {
    public static let title = String(localized: "Allow ShortcutLens to use Accessibility", bundle: .module)

    /// The one-line description on the first step.
    public static let welcome = String(
        localized: "See every keyboard shortcut of the app you're using.",
        bundle: .module
    )

    public static let holdCommand = String(
        localized: "Hold Command to show the shortcuts. Click one to use it.",
        bundle: .module
    )

    public static let pressCommandTwice = String(localized: "Press Command twice to search them.", bundle: .module)

    public static let explanation = String(localized: """
    ShortcutLens needs Accessibility to read the menus of the app you're using and \
    to click a menu item when you choose it. It doesn't read what's in your \
    windows or what you type, and it doesn't save what it reads.
    """, bundle: .module)

    public static let noData = String(localized: "ShortcutLens collects nothing and sends nothing.", bundle: .module)

    public static let instructions = String(localized: """
    Open System Settings and turn on ShortcutLens under Privacy & Security > \
    Accessibility, then come back here.
    """, bundle: .module)

    /// Shown in place of the explanation once the permission is granted.
    public static let ready = String(
        localized: "ShortcutLens is ready. Hold down Command in any app to try it.",
        bundle: .module
    )
    /// Spoken by VoiceOver when the permission is granted.
    public static let grantedAnnouncement = String(localized: "Accessibility allowed", bundle: .module)

    public static let skipButton = String(localized: "Skip", bundle: .module)
    public static let backButton = String(localized: "Back", bundle: .module)
    public static let openSettingsButton = String(localized: "Open System Settings", bundle: .module)
    /// Menu bar entry shown while the permission is missing.
    public static let menuItem = String(localized: "Accessibility Permission Required…", bundle: .module)
}
