import ShortcutLensCore
import SwiftUI

@main
struct ShortcutLensApp: App {
    private let version = AppVersion(infoDictionary: Bundle.main.infoDictionary ?? [:])

    var body: some Scene {
        MenuBarExtra("ShortcutLens", systemImage: "keyboard") {
            Text("ShortcutLens \(version.displayString)")
            Divider()
            Button("Quit ShortcutLens") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
