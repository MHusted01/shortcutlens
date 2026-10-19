import CoreFoundation
import ShortcutLensCore

/// Writes App Shortcuts (`NSUserKeyEquivalents`) into one app's preferences.
///
/// Only the app's own domain is written, never the global "All Applications"
/// one. Like `UserKeyEquivalentSource` this is a local preferences change;
/// the app reads it when it next launches. Sandboxed apps read their
/// container instead, so writing for them has no effect (#54).
enum UserKeyEquivalentWriter {
    enum Failure: Error {
        /// The value read back after writing is not the one written.
        case notSaved
    }

    private static let key = "NSUserKeyEquivalents"

    /// Sets `entry`, replacing the item's previous entry.
    static func set(_ entry: UserKeyEquivalent, bundleID: String) throws(Failure) {
        let updated = UserKeyEquivalent.setting(entry, in: entries(in: bundleID))
        try write(updated, bundleID: bundleID)
        guard entries(in: bundleID)[entry.storeKey] as? String == entry.storeValue else {
            throw .notSaved
        }
    }

    /// Removes the entry for the item at `menuPath`, if there is one.
    static func remove(menuPath: [String], bundleID: String) throws(Failure) {
        let updated = UserKeyEquivalent.removing(menuPath: menuPath, from: entries(in: bundleID))
        try write(updated, bundleID: bundleID)
        guard entries(in: bundleID)[UserKeyEquivalent.storeKey(for: menuPath)] == nil else {
            throw .notSaved
        }
    }

    /// Whether the app's own preferences have an entry for the item at `menuPath`.
    static func hasEntry(menuPath: [String], bundleID: String) -> Bool {
        entries(in: bundleID)[UserKeyEquivalent.storeKey(for: menuPath)] != nil
    }

    /// The app's own entries, without the global ones. Synchronizing first
    /// picks up edits made elsewhere, e.g. in System Settings.
    private static func entries(in bundleID: String) -> [String: Any] {
        let domain = bundleID as CFString
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let value = CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return value as? [String: Any] ?? [:]
    }

    /// Writes `entries`, or deletes the key when none are left.
    private static func write(_ entries: [String: Any], bundleID: String) throws(Failure) {
        let domain = bundleID as CFString
        let value = entries.isEmpty ? nil : entries as CFDictionary
        CFPreferencesSetValue(key as CFString, value, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw .notSaved
        }
    }
}
