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

/// Starts the permission check at launch, before any menu is opened.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permission = PermissionController()

    func applicationDidFinishLaunching(_: Notification) {
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
