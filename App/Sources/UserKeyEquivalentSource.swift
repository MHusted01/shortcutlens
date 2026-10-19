import CoreFoundation
import Foundation
import os
import ShortcutLensCore

/// Reads the App Shortcuts (`NSUserKeyEquivalents`) for one app.
///
/// This is a local preferences read, like `SystemHotKeySource`: nothing leaves
/// the machine, and it runs in the background menu read because synchronizing
/// can wait on cfprefsd. Sandboxed apps keep their preferences in their
/// container, which CFPreferences does not reach. Their file is read directly
/// only when the user turned that on, because macOS asks first (#54).
enum UserKeyEquivalentSource {
    /// A string, not `CFString`: a `CFString` static is not `Sendable`.
    private static let key = "NSUserKeyEquivalents"
    private static let log = Logger(subsystem: "dev.shortcutlens", category: "appshortcuts")

    /// The global entries plus those of `bundleID`; empty when none are set.
    /// With `readsContainer`, the app's entries come from its sandbox
    /// container, falling back to the plain read when that fails.
    static func equivalents(bundleID: String?, readsContainer: Bool = false) -> UserKeyEquivalents {
        let app = bundleID.map { id in
            (readsContainer ? containerEntries(of: id) : nil) ?? entries(in: id as CFString)
        } ?? []
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

    /// The entries in the app's container preferences; nil when the file is
    /// missing, not permitted, not a regular file or not a valid plist.
    /// Opening it is what may show the macOS "access data from other apps"
    /// prompt; a denial fails with `EPERM` and is logged without the app.
    private static func containerEntries(of bundleID: String) -> [UserKeyEquivalent]? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let url = SandboxContainer.preferencesFile(bundleID: bundleID, home: home) else {
            return nil
        }
        // Non-blocking and checked on the descriptor, like `PackSource`, so a
        // FIFO or other special file can neither block nor be read.
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else {
            let code = errno
            log.notice("container preferences not read, errno \(code, privacy: .public)")
            return nil
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              let data = try? handle.read(upToCount: SandboxContainer.maxPreferencesSize + 1),
              let entries = SandboxContainer.equivalents(fromPreferences: data)
        else {
            log.notice("container preferences not usable")
            return nil
        }
        return entries
    }
}
