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
            Text(verbatim: "ShortcutLens \(version.displayString)")
            Button("Settings…") {
                appDelegate.settings.showWindow()
            }
            .keyboardShortcut(",")
            Divider()
            // Exports the app that was frontmost when the menu opened.
            Button("Export Shortcuts as Markdown…") {
                appDelegate.exporter.exportMarkdown()
            }
            .disabled(!appDelegate.permission.permission.isGranted)
            Button("Print Shortcuts…") {
                appDelegate.exporter.printSheet()
            }
            .disabled(!appDelegate.permission.permission.isGranted)
            // Quizzes the app that was frontmost when the menu opened.
            Button("Practice Shortcuts…") {
                appDelegate.practice.start()
            }
            .disabled(!appDelegate.permission.permission.isGranted)
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
    let settings = SettingsController()
    let exporter = CheatSheetExporter()
    let practice = PracticeController()
    private let trigger = TriggerController()
    private let overlay = OverlayController()
    private let editor = ShortcutEditor()
    /// Lives as long as the app, so it is never removed.
    private var layoutObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        apply(settings.settings)
        settings.onChange = { [weak self] in self?.apply($0) }
        trigger.onArm = { [overlay] in overlay.prepare() }
        trigger.onShow = { [overlay] in overlay.show() }
        trigger.onHide = { [overlay] in overlay.hide() }
        trigger.onShowPalette = { [overlay] in overlay.showPalette() }
        overlay.onClosePalette = { [trigger] in trigger.closePalette() }
        overlay.onEditShortcut = { [editor] in editor.show($0) }
        layoutObserver = KeyboardLayout.observeChanges { [overlay] in overlay.keyboardLayoutChanged() }
        permission.onChange = { [trigger] in trigger.setEnabled($0.isGranted) }
        permission.start()
    }

    private func apply(_ settings: AppSettings) {
        trigger.setDelay(settings.triggerDelay)
        overlay.apply(settings)
        exporter.apply(settings)
        practice.apply(settings)
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
