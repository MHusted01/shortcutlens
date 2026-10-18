import AppKit
import ShortcutLensCore

/// The background menu read.
extension OverlayController {
    /// Seconds one menu read may take in total before it stops asking the app.
    private nonisolated static let readBudget: TimeInterval = 3

    /// What one read produced, and whether it ran out of budget.
    struct ReadResult {
        let content: OverlayContent<AXUIElement>
        let systemShortcuts: [MenuShortcut]
        let budgetSpent: Bool
        let settings: AppSettings
    }

    /// Reads the menus, system shortcuts and App Shortcuts of one app. Runs
    /// off the main actor.
    nonisolated static func readContent(
        pid: pid_t,
        bundleID: String?,
        appName: String,
        settings: AppSettings
    ) -> UncheckedSendable<ReadResult> {
        let start = ContinuousClock.now
        let client = DeadlineAXClient(base: SystemAXClient(), budget: readBudget) {
            ProcessInfo.processInfo.systemUptime
        }
        let reader = MenuReader(
            client: client, maxDepth: settings.maxMenuDepth, includesDisabled: settings.showsDisabledItems
        )
        let groups = reader.read(processID: pid)
        let system = settings.showsSystemShortcuts ? SystemHotKeySource.shortcuts() : []
        let custom = UserKeyEquivalentSource.equivalents(bundleID: bundleID)
        let content = OverlayContent(appName: appName, groups: groups, custom: custom)
        let elapsed = ContinuousClock.now - start
        let rows = content.rowCount
        let expired = client.hasExpired
        // Counts and timing only, never app names or titles.
        log.notice("read \(rows) shortcuts in \(elapsed, privacy: .public), budget spent: \(expired, privacy: .public)")
        return UncheckedSendable(value: ReadResult(
            content: content, systemShortcuts: system, budgetSpent: expired, settings: settings
        ))
    }
}
