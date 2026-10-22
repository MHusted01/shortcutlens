import AppKit

/// The app a menu bar command works on, captured before ShortcutLens
/// activates for its own windows.
struct FrontmostApp {
    let pid: pid_t
    let bundleID: String?
    let name: String

    /// The frontmost app unless it is ShortcutLens itself, e.g. while its
    /// Settings window is in front.
    static func current() -> Self? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return nil
        }
        return Self(pid: app.processIdentifier, bundleID: app.bundleIdentifier, name: app.localizedName ?? "")
    }
}
