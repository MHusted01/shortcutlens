import Foundation
import Security

/// Tells whether an app runs in the App Sandbox, from its code signature.
///
/// Sandboxed apps keep their preferences in their container, so App Shortcuts
/// written to `~/Library/Preferences` do not reach them (#54). The signature
/// is read from the bundle on disk; the app's container is never touched, so
/// no "access data from other apps" prompt appears.
enum AppSandbox {
    private static let entitlement = "com.apple.security.app-sandbox"

    /// False when the signature cannot be read, e.g. for an unsigned app.
    static func isSandboxed(bundleURL: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &code) == errSecSuccess, let code else {
            return false
        }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &info) == errSecSuccess,
              let info = info as? [String: Any],
              let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        else {
            return false
        }
        return entitlements[entitlement] as? Bool ?? false
    }
}
