import AppKit
import ShortcutLensCore

/// Reads the menus of the app the overlay is for, off the main actor, and
/// keeps the last read of each running app.
///
/// `load(_:)` returns the app's cached content at once and starts a fresh
/// read; `onContent` gets the result. Each `load(_:)` is a new request, and
/// `MenuReadTracker` decides which finished reads are cached and shown. The
/// cache holds menu and pack content only: system shortcuts are appended to
/// every content handed out.
@MainActor
final class OverlayContentLoader {
    /// Apps whose content stays cached.
    private static let cacheCapacity = 8

    /// One running instance of an app. A relaunched app gets a new key even
    /// if the system reuses its pid.
    private struct AppKey: Hashable {
        let pid: pid_t
        let launchDate: Date?

        init(_ app: NSRunningApplication) {
            pid = app.processIdentifier
            launchDate = app.launchDate
        }
    }

    /// What a read needs to know about the app.
    private struct Request {
        let processID: pid_t
        let bundleID: String?
        let name: String
    }

    private typealias ReadTask = Task<UncheckedSendable<AppContentReader.Result>, Never>
    private typealias Tracker = MenuReadTracker<AppKey, ReadTask>

    /// Called with fresh content for the latest request.
    var onContent: (OverlayContent<AXUIElement>) -> Void = { _ in }

    private var tracker = Tracker(settings: .defaults)
    private var cache = MenuCache<AppKey, OverlayContent<AXUIElement>>(capacity: cacheCapacity)
    private var request: Request?
    private var systemShortcuts: [MenuShortcut] = []
    /// Lives as long as the app, so it is never removed.
    private var terminationObserver: NSObjectProtocol?

    init() {
        observeTerminations()
    }

    /// Drops the cached content of apps that quit.
    private func observeTerminations() {
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let key = AppKey(app)
            MainActor.assumeIsolated {
                self?.forget(key)
            }
        }
    }

    private func forget(_ key: AppKey) {
        cache = cache.removing(key)
    }

    /// Starts a request for `app`: returns its cached content, if any, and
    /// starts reading it. Nil `app` means there is nothing to show; reads
    /// asked for before are no longer shown.
    func load(_ app: NSRunningApplication?) -> OverlayContent<AXUIElement>? {
        tracker = tracker.nextGeneration()
        guard let app else {
            request = nil
            return nil
        }
        let request = Request(
            processID: app.processIdentifier, bundleID: app.bundleIdentifier, name: app.localizedName ?? ""
        )
        self.request = request
        let key = AppKey(app)
        read(key, for: request)
        return cache.value(for: key).map(withSystemShortcuts)
    }

    /// Uses `settings` from the next menu read on. Settings that change what
    /// a read returns drop the cached content and stop reusing a running read.
    func apply(_ settings: AppSettings) {
        let (tracker, dropsCache) = tracker.applying(settings)
        self.tracker = tracker
        if dropsCache {
            cache = MenuCache(capacity: Self.cacheCapacity)
        }
        systemShortcuts = settings.showsSystemShortcuts ? systemShortcuts : []
    }

    /// Drops system shortcuts labelled for the previous layout and stops
    /// reusing a read started before the switch. Menu content stays cached.
    /// Returns false when nothing changed: without system shortcuts no label
    /// depends on the layout.
    func keyboardLayoutChanged() -> Bool {
        guard let changed = tracker.changingLayout() else {
            return false
        }
        OverlayLog.logger.notice("keyboard layout changed, dropping system shortcut labels")
        tracker = changed
        systemShortcuts = []
        return true
    }

    /// Reads the latest request's app again in the same request, and returns
    /// its cached content. Nil when there is no request or the app quit.
    func reload() -> OverlayContent<AXUIElement>? {
        guard let request, let app = NSRunningApplication(processIdentifier: request.processID) else {
            return nil
        }
        let key = AppKey(app)
        read(key, for: request)
        return cache.value(for: key).map(withSystemShortcuts)
    }

    /// Reads `key`'s menus for `request`, reusing a running read.
    private func read(_ key: AppKey, for request: Request) {
        let read = tracker.running(for: key) ?? startRead(key: key, request: request)
        let stamp = tracker.stamp
        Task { [weak self] in
            let result = await read.value
            self?.finish(result.value, key: key, stamp: stamp)
        }
    }

    private func startRead(key: AppKey, request: Request) -> ReadTask {
        let (pid, bundleID, appName) = (request.processID, request.bundleID, request.name)
        let settings = tracker.settings
        let layout = settings.showsSystemShortcuts ? KeyboardLayout.current() : .none
        let task = Task.detached(priority: .userInitiated) {
            AppContentReader.read(pid: pid, bundleID: bundleID, appName: appName, settings: settings, layout: layout)
        }
        tracker = tracker.started(task, for: key)
        return task
    }

    private func finish(_ result: AppContentReader.Result, key: AppKey, stamp: Tracker.Stamp) {
        let (tracker, outcome) = tracker.finishing(
            key, stamp: stamp, settings: result.settings, appTerminated: Self.hasTerminated(key)
        )
        self.tracker = tracker
        if outcome.caches {
            cache = cache.storing(read: result.content, for: key, budgetSpent: result.budgetSpent)
        }
        switch outcome.next {
        case .none:
            return
        case .readAgain:
            // Settings or layout changed during this read; read again so an open panel
            // does not stay on the loading state.
            if let request {
                read(key, for: request)
            }
        case .show:
            // A read started before the toggle was turned off must not bring them back.
            systemShortcuts = tracker.settings.showsSystemShortcuts ? result.systemShortcuts : []
            onContent(withSystemShortcuts(cache.value(for: key) ?? result.content))
        }
    }

    private func withSystemShortcuts(_ content: OverlayContent<AXUIElement>) -> OverlayContent<AXUIElement> {
        content.appending(sectionTitle: SystemHotKeyCatalog.sectionTitle, shortcuts: systemShortcuts)
    }

    /// True when the app `key` names is gone, also when its pid now belongs to another app.
    private static func hasTerminated(_ key: AppKey) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: key.pid) else {
            return true
        }
        // `launchDate` is nil for some processes; only two different dates mean a reused pid.
        if let then = key.launchDate, let now = app.launchDate, then != now {
            return true
        }
        return app.isTerminated
    }
}
