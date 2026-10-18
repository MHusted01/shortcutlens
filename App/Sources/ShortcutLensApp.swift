import ShortcutLensCore
import SwiftUI

@main
struct ShortcutLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let version = AppVersion(infoDictionary: Bundle.main.infoDictionary ?? [:])

    var body: some Scene {
        MenuBarExtra {
            if !appDelegate.permission.permission.isGranted {
                Button(OnboardingText.menuItem) {
                    appDelegate.permission.showOnboarding()
                }
                Divider()
            }
            Text("ShortcutLens \(version.displayString)")
            Divider()
            Button("Quit ShortcutLens") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            MenuBarIcon(permission: appDelegate.permission)
        }
    }
}

/// Starts the permission check at launch, before any menu is opened. The
/// Command trigger runs only while the permission is granted.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permission = PermissionController()
    private let trigger = TriggerController()
    private let overlay = OverlayController()

    func applicationDidFinishLaunching(_: Notification) {
        trigger.onArm = { [overlay] in overlay.prepare() }
        trigger.onShow = { [overlay] in overlay.show() }
        trigger.onHide = { [overlay] in overlay.hide() }
        permission.onChange = { [trigger] in trigger.setEnabled($0.isGranted) }
        permission.start()
    }
}

/// The menu bar icon; a warning sign while the permission is missing.
private struct MenuBarIcon: View {
    let permission: PermissionController

    var body: some View {
        Image(systemName: permission.permission.isGranted ? "keyboard" : "exclamationmark.triangle")
            .accessibilityLabel("ShortcutLens")
    }
}
