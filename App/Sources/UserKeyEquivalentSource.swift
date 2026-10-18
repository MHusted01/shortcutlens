import CoreFoundation
import ShortcutLensCore

/// Reads the App Shortcuts (`NSUserKeyEquivalents`) for one app.
///
/// This is a local preferences read, like `SystemHotKeySource`: nothing leaves
/// the machine, and it runs in the background menu read because synchronizing
/// can wait on cfprefsd. Sandboxed apps keep their preferences in their
/// container, which this read does not reach, so only global entries apply
/// to them.
enum UserKeyEquivalentSource {
    /// A string, not `CFString`: a `CFString` static is not `Sendable`.
    private static let key = "NSUserKeyEquivalents"

    /// The global entries plus those of `bundleID`; empty when none are set.
    static func equivalents(bundleID: String?) -> UserKeyEquivalents {
        let app = bundleID.map { entries(in: $0 as CFString) } ?? []
        return UserKeyEquivalents(global: entries(in: kCFPreferencesAnyApplication), app: app)
    }

    /// The entries stored in exactly this domain, without the global fallback
    /// `CFPreferencesCopyAppValue` would add.
    private static func entries(in domain: CFString) -> [UserKeyEquivalent] {
        // Drops this process's cached copy, so edits made in System Settings
        // since the last read are picked up.
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let value = CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return UserKeyEquivalent.parse(value as? [String: Any] ?? [:])
    }
}
