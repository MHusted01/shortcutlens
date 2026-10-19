/// Which sandboxed apps' container preferences may still be read, and which
/// App Shortcuts a read gives (#54).
///
/// Once macOS denies access to an app's container, asking again on every
/// overlay only repeats the failure, so that app is skipped until the
/// denials are forgotten (the setting is toggled or ShortcutLens relaunches).
public struct ContainerReads: Equatable, Sendable {
    /// What reading one app's container preferences gave.
    public enum Outcome: Equatable, Sendable {
        /// The file was read; empty when it has no App Shortcuts.
        case read([UserKeyEquivalent])
        /// macOS refused access (`EPERM` or `EACCES`).
        case denied
        /// Missing, not a regular file or not a valid plist.
        case unavailable
    }

    private let denied: Set<String>

    public init() {
        self.init(denied: [])
    }

    private init(denied: Set<String>) {
        self.denied = denied
    }

    public func shouldRead(bundleID: String) -> Bool {
        !denied.contains(bundleID)
    }

    /// A copy that remembers a denial for `bundleID`; other outcomes change nothing.
    public func recording(_ outcome: Outcome, for bundleID: String) -> Self {
        outcome == .denied ? Self(denied: denied.union([bundleID])) : self
    }

    /// The app's own entries: the container's when it was read, otherwise the
    /// plain preferences read. `outcome` is nil when the container was not read.
    public static func appEntries(
        _ outcome: Outcome?, fallback: () -> [UserKeyEquivalent]
    ) -> [UserKeyEquivalent] {
        if case let .read(entries) = outcome {
            return entries
        }
        return fallback()
    }
}
