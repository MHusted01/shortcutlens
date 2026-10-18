/// User-facing text of the Accessibility onboarding. `explanation` and `noData`
/// are quoted from PRIVACY.md; a unit test keeps them in sync.
public enum OnboardingText {
    public static let title = "Allow ShortcutLens to use Accessibility"

    public static let explanation = """
    ShortcutLens reads the menu bar of the app in front (menu titles and their \
    keyboard shortcuts) through the macOS Accessibility API, and presses a menu \
    item when you click it in the overlay. It does not read window contents, \
    typed text or other apps' documents, and it does not store what it reads.
    """

    public static let noData = "ShortcutLens collects nothing and sends nothing."

    public static let instructions = """
    Open System Settings and turn on ShortcutLens under Privacy & Security > \
    Accessibility. This window closes by itself once access is granted.
    """

    public static let openSettingsButton = "Open Accessibility Settings"
    public static let laterButton = "Later"
    /// Menu bar entry shown while the permission is missing.
    public static let menuItem = "Accessibility Permission Required…"
}
