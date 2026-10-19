import AppKit
import os
import ShortcutLensCore
import SwiftUI

/// Reads the frontmost app's menus and shows them in `OverlayPanel`; clicking
/// an entry runs that menu item.
///
/// `prepare()` runs when the hold-Command countdown starts and reads the menus
/// off the main actor, so by the time `show()` runs a second later the content
/// is usually ready. The last read of each running app is cached, so a
/// reopened app shows it at once while the fresh read runs. Without cached
/// content the panel shows a loading state and fills in when the read
/// finishes. Each `prepare()` starts a new generation; an older generation's
/// result is cached but not shown.
///
/// `showPalette()` shows the same content as a command palette: typing
/// filters, arrow keys select, Return runs. The panel keeps the size it has
/// for all rows while filtering. Every way of closing the palette goes
/// through `onClosePalette`, so the trigger state machine always knows.
///
/// System shortcuts are read with the menus, off the main actor, and appended
/// as a last, display-only section. Favourites are pinned as a first section
/// when content is shown and again when one is toggled. The cache holds menu
/// and pack content only.
@MainActor
final class OverlayController {
    nonisolated static let log = Logger(subsystem: "dev.shortcutlens", category: "overlay")
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

    /// The app a read was started for.
    struct Target {
        let generation: Int
        let name: String
        let processID: pid_t
        let bundleID: String?
        let bundleURL: URL?
        let icon: NSImage?
    }

    /// The open palette and the screen area it was opened on.
    private struct OpenPalette {
        let state: PaletteState<AXUIElement>
        let model: PaletteModel
        let screen: CGRect

        func with(_ state: PaletteState<AXUIElement>) -> Self {
            Self(state: state, model: model, screen: screen)
        }
    }

    private typealias ReadTask = Task<UncheckedSendable<ReadResult>, Never>

    /// Called when the palette should close: Escape on an empty query, an
    /// item was run, or the panel lost key status.
    var onClosePalette: () -> Void = {}
    /// Called with the menu item the user chose "Edit Shortcut…" for, after
    /// the panel closed.
    var onEditShortcut: (ShortcutEditRequest) -> Void = { _ in }

    private let panel = OverlayPanel()
    private var inFlight: (key: AppKey, task: ReadTask)?
    private var generation = 0
    /// Bumped on a keyboard layout switch; older reads have stale system labels.
    private var layoutEpoch = 0
    private(set) var target: Target?
    private(set) var content: OverlayContent<AXUIElement>?
    private var cache = MenuCache<AppKey, OverlayContent<AXUIElement>>(capacity: cacheCapacity)
    private var terminationObserver: NSObjectProtocol?
    private var isShown = false
    private var palette: OpenPalette?
    var isPaletteOpen: Bool {
        palette != nil
    }

    private var readSettings = AppSettings.defaults
    private var systemShortcuts: [MenuShortcut] = []
    /// Changed by `toggleFavourite(_:)`.
    var favourites = Favourites(store: UserDefaults.standard)

    init() {
        panel.onResignKey = { [weak self] in self?.onClosePalette() }
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

    /// Uses `settings` from the next menu read on. Settings that change what
    /// a read returns drop the cached content and stop reusing a running read.
    func apply(_ settings: AppSettings) {
        if settings.changesMenuReads(comparedTo: readSettings) {
            cache = MenuCache(capacity: Self.cacheCapacity)
        }
        if settings.restartsReads(comparedTo: readSettings) {
            inFlight = nil
        }
        readSettings = settings
        systemShortcuts = settings.showsSystemShortcuts ? systemShortcuts : []
    }

    /// Drops system shortcuts labelled for the previous layout and stops
    /// reusing a read started before the switch. Menu content stays cached.
    /// Without system shortcuts no label depends on the layout.
    func keyboardLayoutChanged() {
        guard readSettings.showsSystemShortcuts else {
            return
        }
        Self.log.notice("keyboard layout changed, dropping system shortcut labels")
        layoutEpoch += 1
        inFlight = nil
        systemShortcuts = []
        rereadOpenPanel()
    }

    /// An open panel or palette drops the old system section at once and
    /// shows the new one when the read finishes.
    private func rereadOpenPanel() {
        guard isShown || palette != nil, let target,
              let app = NSRunningApplication(processIdentifier: target.processID)
        else {
            return
        }
        let key = AppKey(app)
        if let cached = cache.value(for: key) {
            display(decorated(cached, bundleID: target.bundleID))
        }
        read(key, for: target)
    }

    /// Starts reading the frontmost app's menus and shows its cached content
    /// until the read finishes. ShortcutLens itself is skipped.
    func prepare() {
        generation += 1
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            target = nil
            content = nil
            return
        }
        let key = AppKey(app)
        content = cache.value(for: key).map { decorated($0, bundleID: app.bundleIdentifier) }
        let target = Target(
            generation: generation, name: app.localizedName ?? "", processID: app.processIdentifier,
            bundleID: app.bundleIdentifier,
            bundleURL: app.bundleURL, icon: app.icon
        )
        self.target = target
        read(key, for: target)
    }

    /// Reads `key`'s menus for `target`, reusing a running read.
    private func read(_ key: AppKey, for target: Target) {
        let read = runningRead(for: key) ?? startRead(key: key, target: target)
        let epoch = layoutEpoch
        Task { [weak self] in
            let result = await read.value
            self?.finishRead(result.value, generation: target.generation, key: key, layoutEpoch: epoch)
        }
    }

    /// The read already running for `key`, if any. Reusing it keeps repeated
    /// Command holds on a slow app from piling up concurrent menu walks.
    private func runningRead(for key: AppKey) -> ReadTask? {
        inFlight?.key == key ? inFlight?.task : nil
    }

    private func startRead(key: AppKey, target: Target) -> ReadTask {
        let (pid, bundleID, appName) = (key.pid, target.bundleID, target.name)
        let settings = readSettings
        let layout = settings.showsSystemShortcuts ? KeyboardLayout.current() : .none
        let task = Task.detached(priority: .userInitiated) {
            Self.readContent(pid: pid, bundleID: bundleID, appName: appName, settings: settings, layout: layout)
        }
        inFlight = (key, task)
        return task
    }

    /// Shows the panel for the app `prepare()` captured.
    func show() {
        guard target != nil else {
            return
        }
        isShown = true
        render()
    }

    /// Shows the panel as a palette that takes typed keys. Closes the palette
    /// again when there is nothing to show it for.
    func showPalette() {
        guard let target, let screen = Self.visibleFrameUnderPointer() else {
            onClosePalette()
            return
        }
        let model = PaletteModel(
            onQueryChange: { [weak self] query in self?.updatePalette { $0.with(query: query) } },
            onCommand: { [weak self] command in self?.handle(command) ?? false }
        )
        let state = content.map { PaletteState().with(content: $0) } ?? PaletteState()
        palette = OpenPalette(state: state, model: model, screen: screen)
        isShown = true
        let select: (OverlayRow<AXUIElement>) -> Void = { [weak self] row in self?.runFromPalette(row) }
        let view = OverlayView(
            appName: target.name, icon: target.icon, content: .loading, palette: model, onSelect: select,
            onEdit: { [weak self] id, row in self?.edit(row, id: id) },
            onFavourite: favouriteHandler
        )
        let size = refreshPalette()
        panel.present(view, frame: ScreenPicker.centeredFrame(size: size, in: screen), takesKeyboard: true)
        Self.log.notice("palette shown")
    }

    func hide() {
        isShown = false
        palette = nil
        panel.dismiss()
    }

    private func updatePalette(_ change: (PaletteState<AXUIElement>) -> PaletteState<AXUIElement>) {
        guard let palette else {
            return
        }
        self.palette = palette.with(change(palette.state))
        refreshPalette()
    }

    /// Copies the palette state into the view model. Returns the panel size
    /// for all rows, which filtering does not change.
    @discardableResult
    private func refreshPalette() -> CGSize {
        guard let palette else {
            return .zero
        }
        let (body, size) = Self.layout(palette.state.content, in: palette.screen)
        palette.model.query = palette.state.query
        palette.model.selection = palette.state.selection
        palette.model.body = Self.paletteBody(palette.state, unfiltered: body, size: size)
        return size
    }

    private func runFromPalette(_ row: OverlayRow<AXUIElement>) {
        onClosePalette()
        run(row)
    }

    private func finishRead(_ result: ReadResult, generation: Int, key: AppKey, layoutEpoch: Int) {
        // A read made with older settings or layout is not the one in flight
        // (`apply(_:)` or `keyboardLayoutChanged()` dropped it), and is neither cached nor shown.
        let isCurrent = !readSettings.restartsReads(comparedTo: result.settings) && layoutEpoch == self.layoutEpoch
        if isCurrent, inFlight?.key == key {
            inFlight = nil
        }
        // A read that outlived its app would re-add an entry nothing removes.
        if isCurrent, !Self.hasTerminated(key) {
            cache = cache.storing(read: result.content, for: key, budgetSpent: result.budgetSpent)
        }
        guard generation == self.generation else {
            return
        }
        guard isCurrent else {
            // Settings or layout changed during this read; read again so an open panel
            // does not stay on the loading state.
            if let target {
                read(key, for: target)
            }
            return
        }
        // A read started before the toggle was turned off must not bring them back.
        systemShortcuts = readSettings.showsSystemShortcuts ? result.systemShortcuts : []
        display(decorated(cache.value(for: key) ?? result.content, bundleID: target?.bundleID))
    }

    /// Makes `content` the shown content and updates an open panel or palette.
    func display(_ content: OverlayContent<AXUIElement>) {
        self.content = content
        if let palette {
            self.palette = palette.with(palette.state.with(content: content))
            let size = refreshPalette()
            panel.setFrame(ScreenPicker.centeredFrame(size: size, in: palette.screen), display: true)
        } else if isShown {
            render()
        }
    }

    private func render() {
        guard let target, let visible = Self.visibleFrameUnderPointer() else {
            return
        }
        let (body, size) = Self.layout(content, in: visible)
        let view = OverlayView(
            appName: target.name, icon: target.icon, content: body,
            onSelect: { [weak self] row in self?.run(row) },
            onEdit: { [weak self] id, row in self?.edit(row, id: id) },
            onFavourite: favouriteHandler
        )
        panel.present(view, frame: ScreenPicker.centeredFrame(size: size, in: visible))
    }

    /// Cached content with the system shortcuts after it and the favourites before it.
    private func decorated(_ content: OverlayContent<AXUIElement>, bundleID: String?) -> OverlayContent<AXUIElement> {
        content.appending(sectionTitle: SystemHotKeyCatalog.sectionTitle, shortcuts: systemShortcuts)
            .pinning(favourites.paths(for: bundleID))
    }
}

/// Palette key handling.
extension OverlayController {
    /// Returns false only for Left/Right without another column to move to,
    /// so the search field moves its cursor instead.
    private func handle(_ command: SearchCommand) -> Bool {
        guard let palette else {
            return false
        }
        switch command {
        case .moveUp:
            updatePalette { $0.movingSelection(by: -1) }
        case .moveDown:
            updatePalette { $0.movingSelection(by: 1) }
        case .moveLeft:
            return moveColumn(by: -1)
        case .moveRight:
            return moveColumn(by: 1)
        case .submit:
            guard let row = palette.state.selectedRow, row.isRunnable else {
                NSSound.beep()
                return true
            }
            runFromPalette(row)
        case .cancel:
            switch palette.state.escaped() {
            case let .cleared(state):
                updatePalette { _ in state }
            case .close:
                onClosePalette()
            }
        }
        return true
    }

    /// Moves the selection between the columns currently shown. Returns
    /// false when the selection did not change (no selection, one column).
    private func moveColumn(by offset: Int) -> Bool {
        guard case let .shortcuts(_, columns, _) = palette?.model.body else {
            return false
        }
        let before = palette?.state.selection
        updatePalette { $0.movingSelection(columns: offset, in: columns, metrics: .standard) }
        return palette?.state.selection != before
    }
}

extension OverlayController {
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
