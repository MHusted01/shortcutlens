import CoreFoundation
import ShortcutLensCore

/// Reads the macOS system shortcuts from `com.apple.symbolichotkeys`.
///
/// This is a local preferences read: no file access outside the preferences
/// system and nothing leaves the machine. The app is not sandboxed, so another
/// domain's preferences are readable. Synchronizing can wait on cfprefsd, so
/// this runs in the background menu read, never on the main actor.
enum SystemHotKeySource {
    // Strings, not `CFString`: a `CFString` static is not `Sendable`.
    private static let domain = "com.apple.symbolichotkeys"
    private static let key = "AppleSymbolicHotKeys"

    /// The enabled system shortcuts. A missing or unreadable store yields the
    /// built-in defaults. Character keys are labelled for `layout`.
    static func shortcuts(layout: KeyLabels) -> [MenuShortcut] {
        let domain = domain as CFString
        // Drops this process's cached copy, so changes made in System
        // Settings since the last read are picked up.
        CFPreferencesAppSynchronize(domain)
        let value = CFPreferencesCopyAppValue(key as CFString, domain) as? [String: Any] ?? [:]
        return SystemHotKeyCatalog.shortcuts(from: SymbolicHotKeyParser.parse(value), layout: layout)
    }
}
