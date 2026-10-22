import AppKit
import ShortcutLensCore

/// Reads everything the overlay, the palette, Practice and Export show for
/// one app: its menus, shortcut packs, App Shortcuts and system shortcuts.
enum AppContentReader {
    /// Seconds one menu read may take in total before it stops asking the app.
    private static let readBudget: TimeInterval = 3

    /// What one read produced, and whether it ran out of budget.
    struct Result {
        let content: OverlayContent<AXUIElement>
        let systemShortcuts: [MenuShortcut]
        let budgetSpent: Bool
        let settings: AppSettings
    }

    /// Reads the menus, shortcut packs, system shortcuts and App Shortcuts of
    /// one app. Pack sections follow the menus. Call it off the main actor:
    /// the menu walk can take up to `readBudget`. The caller takes the
    /// keyboard `layout` snapshot on the main actor.
    ///
    /// The result holds `AXUIElement`s, which are not `Sendable`, so it is
    /// wrapped to leave the detached task that runs the read.
    static func read(
        pid: pid_t,
        bundleID: String?,
        appName: String,
        settings: AppSettings,
        layout: KeyLabels
    ) -> UncheckedSendable<Result> {
        let start = ContinuousClock.now
        let client = DeadlineAXClient(base: SystemAXClient(), budget: readBudget) {
            ProcessInfo.processInfo.systemUptime
        }
        let reader = MenuReader(
            client: client, maxDepth: settings.maxMenuDepth, includesDisabled: settings.showsDisabledItems
        )
        let signposter = OverlayLog.signposter
        let interval = signposter.beginInterval("read")
        defer { signposter.endInterval("read", interval) }
        let groups = signposter.withIntervalSignpost("menu walk") { reader.read(processID: pid) }
        let system = settings.showsSystemShortcuts ? SystemHotKeySource.shortcuts(layout: layout) : []
        let custom = UserKeyEquivalentSource.equivalents(bundleID: bundleID)
        let packSections = PackSource.library().sections(for: bundleID)
        let content = OverlayContent(appName: appName, groups: groups, custom: custom)
            .appending(sections: packSections.map { (title: $0.title, shortcuts: $0.shortcuts) })
        let elapsed = ContinuousClock.now - start
        let rows = content.rowCount
        let expired = client.hasExpired
        // Counts and timing only, never app names or titles.
        OverlayLog.logger.notice(
            "read \(rows) shortcuts in \(elapsed, privacy: .public), budget spent: \(expired, privacy: .public)"
        )
        return UncheckedSendable(value: Result(
            content: content, systemShortcuts: system, budgetSpent: expired, settings: settings
        ))
    }
}
