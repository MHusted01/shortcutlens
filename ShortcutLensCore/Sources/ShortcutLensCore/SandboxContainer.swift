import Foundation

/// Where a sandboxed app keeps its preferences, and the App Shortcuts in them.
///
/// Sandboxed apps read `NSUserKeyEquivalents` from
/// `~/Library/Containers/<bundle-id>/Data/Library/Preferences/<bundle-id>.plist`,
/// which CFPreferences does not reach from outside the sandbox (#54). The
/// file belongs to another app, so its contents are untrusted.
public enum SandboxContainer {
    /// Bundle identifiers are limited to 255 characters.
    public static let maxBundleIDLength = 255
    /// Larger preference files are not read; App Shortcuts are a few KB.
    public static let maxPreferencesSize = 4 * 1024 * 1024

    private static let key = "NSUserKeyEquivalents"
    private static let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"
    )

    /// The preferences file of the app with `bundleID`, nil when the ID is
    /// not a plain reverse-DNS identifier and could leave the container.
    public static func preferencesFile(bundleID: String, home: URL) -> URL? {
        guard isPlainIdentifier(bundleID) else {
            return nil
        }
        return home.appending(path: "Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist")
    }

    /// The App Shortcuts in a preferences file's data; empty when none are
    /// set, nil when the data is too large or not a dictionary plist.
    public static func equivalents(fromPreferences data: Data) -> [UserKeyEquivalent]? {
        guard data.count <= maxPreferencesSize,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let preferences = plist as? [String: Any]
        else {
            return nil
        }
        return UserKeyEquivalent.parse(preferences[key] as? [String: Any] ?? [:])
    }

    /// Non-empty, not too long, allowed characters only, no leading dot and
    /// no empty component, so `.` and `..` can never appear in the path.
    private static func isPlainIdentifier(_ bundleID: String) -> Bool {
        !bundleID.isEmpty && bundleID.count <= maxBundleIDLength
            && bundleID.unicodeScalars.allSatisfy(allowed.contains)
            && !bundleID.split(separator: ".", omittingEmptySubsequences: false).contains(where: \.isEmpty)
    }
}
