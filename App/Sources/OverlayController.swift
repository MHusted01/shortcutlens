import AppKit
import os
import ShortcutLensCore
import SwiftUI

/// Reads the frontmost app's menus and shows them in `OverlayPanel`.
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

    private let panel = OverlayPanel()
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
        let name = target.name
        let read = Task.detached(priority: .userInitiated) {
            Self.readContent(pid: pid, appName: name)
        }
        Task { [weak self] in
            let result = await read.value
            self?.finishRead(result.value, generation: target.generation)
        }
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

    private func finishRead(_ content: OverlayContent<AXUIElement>, generation: Int) {
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
        let view = OverlayView(appName: target.name, icon: target.icon, content: body)
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
    /// The body to show and the panel size it needs on a screen whose visible
    /// area is `visible`. Nil `content` means the read is still running.
    static func layout(_ content: OverlayContent<AXUIElement>?, in visible: CGRect) -> (OverlayBody, CGSize) {
        guard let content else {
            return (.loading, OverlayMetrics.placeholderSize)
        }
        guard !content.isEmpty else {
            return (.empty, OverlayMetrics.placeholderSize)
        }
        let padding = OverlayMetrics.padding * 2
        let chrome = padding + OverlayMetrics.headerHeight + OverlayMetrics.dividerHeight
            + OverlayMetrics.sectionSpacing
        let maxWidth = visible.width * OverlayMetrics.screenFraction - padding
        let maxHeight = visible.height * OverlayMetrics.screenFraction - chrome
        let heights = content.sections.map { OverlayMetrics.sectionHeight(rows: $0.rows.count) }
        let maxColumns = ColumnLayout.columnCount(
            availableWidth: maxWidth,
            columnWidth: OverlayMetrics.columnWidth,
            spacing: OverlayMetrics.columnSpacing
        )
        // Section heights include the spacing below them, but the last section
        // of a column has none, so one spacing is added to the limit and taken
        // off the result.
        let spacing = Int(OverlayMetrics.sectionSpacing)
        let columns = ColumnLayout.layout(heights, maxColumns: maxColumns, maxHeight: Int(maxHeight) + spacing)
        let tallest = (columns.map { ColumnLayout.height(of: $0, in: heights) }.max() ?? 0) - spacing
        let count = CGFloat(columns.count)
        let scrolls = CGFloat(tallest) > maxHeight
        let size = CGSize(
            width: count * OverlayMetrics.columnWidth + (count - 1) * OverlayMetrics.columnSpacing + padding,
            height: min(CGFloat(tallest), maxHeight) + chrome
        )
        return (.shortcuts(sections: content.sections, columns: columns, scrolls: scrolls), size)
    }
}

/// Carries AX elements from the reading task to the main actor.
///
/// `AXUIElement` is an immutable reference to another process's element and
/// the AX API may be called from any thread, but the type is not marked
/// `Sendable`. The value is created once and never mutated after it is sent.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
