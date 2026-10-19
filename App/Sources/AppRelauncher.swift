import AppKit

/// Quits an app and opens it again, so it reads its App Shortcuts anew.
///
/// The app is asked to quit like the Quit menu item would, so it can save
/// or ask about unsaved documents; when it has not quit in time nothing more
/// happens. Finder is the exception: it has no Quit item and macOS restarts
/// it on its own, so it is force-quit when asking does not work.
enum AppRelauncher {
    enum Outcome {
        case relaunched
        /// The app is still running, e.g. the user cancelled a save dialog.
        case didNotQuit
        /// The app quit but could not be opened again.
        case didNotOpen
    }

    private static let finder = "com.apple.finder"
    private static let quitTimeout: Duration = .seconds(10)
    private static let pollInterval: Duration = .milliseconds(100)

    /// Relaunches the app running as `processID`. A pid now used by another
    /// app counts as already quit, so only the app itself is ever quit.
    @MainActor
    static func relaunch(processID: pid_t, bundleID: String, bundleURL: URL) async -> Outcome {
        if let app = NSRunningApplication(processIdentifier: processID), app.bundleIdentifier == bundleID {
            guard await quit(app) else {
                return .didNotQuit
            }
        }
        do {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
            return .relaunched
        } catch {
            return .didNotOpen
        }
    }

    /// True once the app has quit.
    @MainActor
    private static func quit(_ app: NSRunningApplication) async -> Bool {
        app.terminate()
        if await waitUntilTerminated(app) {
            return true
        }
        guard app.bundleIdentifier == finder else {
            return false
        }
        app.forceTerminate()
        return await waitUntilTerminated(app)
    }

    @MainActor
    private static func waitUntilTerminated(_ app: NSRunningApplication) async -> Bool {
        let deadline = ContinuousClock.now + quitTimeout
        while !app.isTerminated, ContinuousClock.now < deadline {
            try? await Task.sleep(for: pollInterval)
        }
        return app.isTerminated
    }
}
