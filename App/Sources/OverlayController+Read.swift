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

    /// Reads the menus, shortcut packs, system shortcuts and App Shortcuts of
    /// one app. Pack sections follow the menus. Runs off the main actor, so
    /// the caller takes the keyboard `layout` snapshot on the main actor.
    nonisolated static func readContent(
        pid: pid_t,
        bundleID: String?,
        appName: String,
        settings: AppSettings,
        layout: KeyLabels
    ) -> UncheckedSendable<ReadResult> {
        let start = ContinuousClock.now
        let client = DeadlineAXClient(base: SystemAXClient(), budget: readBudget) {
            ProcessInfo.processInfo.systemUptime
        }
        let reader = MenuReader(
            client: client, maxDepth: settings.maxMenuDepth, includesDisabled: settings.showsDisabledItems
        )
        let groups = reader.read(processID: pid)
        let system = settings.showsSystemShortcuts ? SystemHotKeySource.shortcuts(layout: layout) : []
        let custom = UserKeyEquivalentSource.equivalents(bundleID: bundleID)
        let packSections = PackSource.library().sections(for: bundleID)
        let content = OverlayContent(appName: appName, groups: groups, custom: custom)
            .appending(sections: packSections.map { (title: $0.title, shortcuts: $0.shortcuts) })
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
