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
    /// Shared by concurrent background reads.
    private static let containerReads = OSAllocatedUnfairLock(initialState: ContainerReads())

    /// The global entries plus those of `bundleID`; empty when none are set.
    /// With `readsContainer`, the app's entries come from its sandbox
    /// container, falling back to the plain read when that fails. An app
    /// whose container was denied once is not asked again.
    static func equivalents(bundleID: String?, readsContainer: Bool = false) -> UserKeyEquivalents {
        let app = bundleID.map { id in
            ContainerReads.appEntries(readsContainer ? containerOutcome(of: id) : nil) {
                entries(in: id as CFString)
            }
        } ?? []
        return UserKeyEquivalents(global: entries(in: kCFPreferencesAnyApplication), app: app)
    }

    /// Lets every app's container be tried again, e.g. after the user
    /// changed the permission and toggled the setting.
    static func forgetContainerDenials() {
        containerReads.withLock { $0 = ContainerReads() }
    }

    /// Reads the container unless it was denied before, and remembers a denial.
    private static func containerOutcome(of bundleID: String) -> ContainerReads.Outcome? {
        guard containerReads.withLock({ $0.shouldRead(bundleID: bundleID) }) else {
            return nil
        }
        let outcome = readContainer(of: bundleID)
        containerReads.withLock { $0 = $0.recording(outcome, for: bundleID) }
        return outcome
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

    /// The entries in the app's container preferences. Opening the file is
    /// what may show the macOS "access data from other apps" prompt; a denial
    /// fails with `EPERM` and is logged without the app.
    private static func readContainer(of bundleID: String) -> ContainerReads.Outcome {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let url = SandboxContainer.preferencesFile(bundleID: bundleID, home: home) else {
            return .unavailable
        }
        // Non-blocking and checked on the descriptor, like `PackSource`, so a
        // FIFO or other special file can neither block nor be read.
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else {
            let code = errno
            log.notice("container preferences not read, errno \(code, privacy: .public)")
            return code == EPERM || code == EACCES ? .denied : .unavailable
        }
        // Closed once, by the `defer`.
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              let data = try? handle.read(upToCount: SandboxContainer.maxPreferencesSize + 1),
              let entries = SandboxContainer.equivalents(fromPreferences: data)
        else {
            log.notice("container preferences not usable")
            return .unavailable
        }
        return .read(entries)
    }
}
