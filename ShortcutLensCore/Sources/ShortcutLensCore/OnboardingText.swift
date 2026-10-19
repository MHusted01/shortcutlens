import Foundation

/// User-facing text of the Accessibility onboarding. `explanation` and `noData`
/// are quoted from PRIVACY.md; a unit test keeps them in sync.
public enum OnboardingText {
    public static let title = String(localized: "Allow ShortcutLens to use Accessibility", bundle: .module)

    public static let explanation = String(localized: """
    ShortcutLens reads the menu bar of the app in front (menu titles and their \
    keyboard shortcuts) through the macOS Accessibility API, and presses a menu \
    item when you click it in the overlay. It does not read window contents, \
    typed text or other apps' documents, and it does not store what it reads.
    """, bundle: .module)

    public static let noData = String(localized: "ShortcutLens collects nothing and sends nothing.", bundle: .module)

    public static let instructions = String(localized: """
    Open System Settings and turn on ShortcutLens under Privacy & Security > \
    Accessibility. This window closes by itself once access is granted.
    """, bundle: .module)

    public static let openSettingsButton = String(localized: "Open Accessibility Settings", bundle: .module)
    public static let laterButton = String(localized: "Later", bundle: .module)
    /// Menu bar entry shown while the permission is missing.
    public static let menuItem = String(localized: "Accessibility Permission Required…", bundle: .module)
}
