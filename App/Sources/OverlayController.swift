import AppKit
import os
import ShortcutLensCore
import SwiftUI

/// Reads the frontmost app's menus and shows them in `OverlayPanel`; clicking
/// an entry runs that menu item.
///
/// `prepare()` runs when the hold-Command countdown starts and reads the menus
/// off the main actor, so by the time `show()` runs a second later the content
/// is usually ready. Otherwise the panel shows a loading state and fills in
/// when the read finishes. Each `prepare()` starts a new generation; results of
/// an older one are dropped.
@MainActor
final class OverlayController {
    private nonisolated static let log = Logger(subsystem: "dev.shortcutlens", category: "overlay")

    /// The app a read was started for.
    private struct Target {
        let generation: Int
        let name: String
        let icon: NSImage?
    }

    private typealias ReadTask = Task<UncheckedSendable<OverlayContent<AXUIElement>>, Never>

    private let panel = OverlayPanel()
    private var inFlight: (pid: pid_t, task: ReadTask)?
    private var generation = 0
    private var target: Target?
    private var content: OverlayContent<AXUIElement>?
    private var isShown = false

    /// Starts reading the frontmost app's menus. ShortcutLens itself is skipped.
    func prepare() {
        generation += 1
        content = nil
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            target = nil
            return
        }
        let target = Target(generation: generation, name: app.localizedName ?? "", icon: app.icon)
        self.target = target
        let pid = app.processIdentifier
        let read = runningRead(for: pid) ?? startRead(pid: pid, appName: target.name)
        Task { [weak self] in
            let result = await read.value
            self?.finishRead(result.value, generation: target.generation, pid: pid)
        }
    }

    /// The read already running for `pid`, if any. Reusing it keeps repeated
    /// Command holds on a slow app from piling up concurrent menu walks.
    private func runningRead(for pid: pid_t) -> ReadTask? {
        inFlight?.pid == pid ? inFlight?.task : nil
    }

    private func startRead(pid: pid_t, appName: String) -> ReadTask {
        let task = Task.detached(priority: .userInitiated) {
            Self.readContent(pid: pid, appName: appName)
        }
        inFlight = (pid, task)
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

    func hide() {
        isShown = false
        panel.orderOut(nil)
    }

    /// Hides the panel and presses the row's menu item in the target app.
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
            if outcome == .pressed {
                Self.log.notice("menu item \(description, privacy: .public)")
            } else {
                Self.log.error("menu item not run: \(description, privacy: .public)")
            }
        }
    }

    private func finishRead(_ content: OverlayContent<AXUIElement>, generation: Int, pid: pid_t) {
        if inFlight?.pid == pid {
            inFlight = nil
        }
        guard generation == self.generation else {
            return
        }
        self.content = content
        if isShown {
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
    ) -> UncheckedSendable<OverlayContent<AXUIElement>> {
        let start = ContinuousClock.now
        let groups = MenuReader(client: SystemAXClient()).read(processID: pid)
        let content = OverlayContent(appName: appName, groups: groups)
        let elapsed = ContinuousClock.now - start
        let rows = content.rowCount
        // Counts and timing only, never app names or titles.
        log.notice("read \(rows) shortcuts in \(elapsed, privacy: .public)")
        return UncheckedSendable(value: content)
    }
}

extension OverlayController {
    private static let placeholderSize = CGSize(width: 360, height: 150)

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
}

/// Carries AX elements between the main actor and background tasks.
///
/// `AXUIElement` is an immutable reference to another process's element and
/// the AX API may be called from any thread, but the type is not marked
/// `Sendable`. The value is created once and never mutated after it is sent.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
