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
@MainActor
final class OverlayController {
    private nonisolated static let log = Logger(subsystem: "dev.shortcutlens", category: "overlay")
    /// Seconds one menu read may take in total before it stops asking the app.
    private nonisolated static let readBudget: TimeInterval = 3
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

    /// What one read produced, and whether it ran out of budget.
    private struct ReadResult {
        let content: OverlayContent<AXUIElement>
        let budgetSpent: Bool
    }

    /// The app a read was started for.
    private struct Target {
        let generation: Int
        let name: String
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

    private let panel = OverlayPanel()
    private var inFlight: (key: AppKey, task: ReadTask)?
    private var generation = 0
    private var target: Target?
    private var content: OverlayContent<AXUIElement>?
    private var cache = MenuCache<AppKey, OverlayContent<AXUIElement>>(capacity: cacheCapacity)
    private var terminationObserver: NSObjectProtocol?
    private var isShown = false
    private var palette: OpenPalette?

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
        content = cache.value(for: key)
        let target = Target(generation: generation, name: app.localizedName ?? "", icon: app.icon)
        self.target = target
        let read = runningRead(for: key) ?? startRead(key: key, appName: target.name)
        Task { [weak self] in
            let result = await read.value
            self?.finishRead(result.value, generation: target.generation, key: key)
        }
    }

    /// The read already running for `key`, if any. Reusing it keeps repeated
    /// Command holds on a slow app from piling up concurrent menu walks.
    private func runningRead(for key: AppKey) -> ReadTask? {
        inFlight?.key == key ? inFlight?.task : nil
    }

    private func startRead(key: AppKey, appName: String) -> ReadTask {
        let pid = key.pid
        let task = Task.detached(priority: .userInitiated) {
            Self.readContent(pid: pid, appName: appName)
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
            appName: target.name, icon: target.icon, content: .loading, palette: model, onSelect: select
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
            guard let row = palette.state.selectedRow else {
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

    /// Hides the panel and presses the row's menu item in the target app. Beeps
    /// when the item was not run (disabled, stale or an AX error).
    ///
    /// The press runs off the main actor because it can wait up to the AX
    /// messaging timeout. The target app stays frontmost throughout: the panel
    /// never activates ShortcutLens.
    private func run(_ row: OverlayRow<AXUIElement>) {
        hide()
        let element = UncheckedSendable(value: row.element)
        Task.detached(priority: .userInitiated) {
            let outcome = MenuItemRunner(client: SystemAXClient()).run(element.value)
            // A fixed outcome string only, never the menu title.
            let description = outcome.logDescription
            guard outcome != .pressed else {
                Self.log.notice("menu item \(description, privacy: .public)")
                return
            }
            Self.log.error("menu item not run: \(description, privacy: .public)")
            // The panel is already hidden, so the beep is the only sign the click did nothing.
            await MainActor.run { NSSound.beep() }
        }
    }

    private func finishRead(_ result: ReadResult, generation: Int, key: AppKey) {
        if inFlight?.key == key {
            inFlight = nil
        }
        // A read that outlived its app would re-add an entry nothing removes.
        if !Self.hasTerminated(key) {
            cache = cache.storing(read: result.content, for: key, budgetSpent: result.budgetSpent)
        }
        guard generation == self.generation else {
            return
        }
        let content = cache.value(for: key) ?? result.content
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
        let view = OverlayView(appName: target.name, icon: target.icon, content: body) { [weak self] row in
            self?.run(row)
        }
        panel.present(view, frame: ScreenPicker.centeredFrame(size: size, in: visible))
    }

    /// The visible frame (without menu bar and Dock) of the screen under the pointer.
    private static func visibleFrameUnderPointer() -> CGRect? {
        let screens = NSScreen.screens
        let index = ScreenPicker.index(for: NSEvent.mouseLocation, in: screens.map(\.frame))
        return (index.map { screens[$0] } ?? NSScreen.main)?.visibleFrame
    }

    private nonisolated static func readContent(
        pid: pid_t,
        appName: String
    ) -> UncheckedSendable<ReadResult> {
        let start = ContinuousClock.now
        let client = DeadlineAXClient(base: SystemAXClient(), budget: readBudget) {
            ProcessInfo.processInfo.systemUptime
        }
        let groups = MenuReader(client: client).read(processID: pid)
        let content = OverlayContent(appName: appName, groups: groups)
        let elapsed = ContinuousClock.now - start
        let rows = content.rowCount
        let expired = client.hasExpired
        // Counts and timing only, never app names or titles.
        log.notice("read \(rows) shortcuts in \(elapsed, privacy: .public), budget spent: \(expired, privacy: .public)")
        return UncheckedSendable(value: ReadResult(content: content, budgetSpent: expired))
    }
}

extension OverlayController {
    private static let placeholderSize = CGSize(width: 360, height: 150)

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

    /// The body to show and the panel size it needs on a screen whose visible
    /// area is `visible`. Nil `content` means the read is still running.
    static func layout(_ content: OverlayContent<AXUIElement>?, in visible: CGRect) -> (OverlayBody, CGSize) {
        guard let content else {
            return (.loading, placeholderSize)
        }
        guard !content.isEmpty else {
            return (.empty, placeholderSize)
        }
        let result = PanelLayout.layout(
            rowCounts: content.sections.map(\.rows.count),
            metrics: .standard,
            visible: visible.size
        )
        return (.shortcuts(sections: content.sections, columns: result.columns, scrolls: result.scrolls), result.size)
    }

    /// The palette's visible rows laid out inside the panel `size` that the
    /// `unfiltered` body needs. Loading and empty states are kept as they are.
    static func paletteBody(_ state: PaletteState<AXUIElement>, unfiltered: OverlayBody, size: CGSize) -> OverlayBody {
        guard case .shortcuts = unfiltered, let visible = state.visible else {
            return unfiltered
        }
        guard !visible.isEmpty else {
            return .noMatches
        }
        let result = PanelLayout.layout(
            rowCounts: visible.sections.map(\.rows.count),
            metrics: .standard,
            fitting: size
        )
        return .shortcuts(sections: visible.sections, columns: result.columns, scrolls: result.scrolls)
    }
}

/// Carries AX elements between the main actor and background tasks.
///
/// `AXUIElement` is an immutable reference to another process's element and
/// the AX API may be called from any thread, but the type is not marked
/// `Sendable`. The value is created once and never mutated after it is sent.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
