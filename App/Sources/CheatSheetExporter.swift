import AppKit
import os
import ShortcutLensCore
import UniformTypeIdentifiers

/// Exports the frontmost app's shortcuts from the menu bar menu, as a
/// Markdown file or through the print panel (which offers Save as PDF).
/// Always exports everything a read returns, without the overlay's filter.
/// Files are written only where the user chooses.
@MainActor
final class CheatSheetExporter {
    private static let log = Logger(subsystem: "dev.shortcutlens", category: "export")

    /// The app whose shortcuts are exported, captured before ShortcutLens
    /// activates for its panels.
    private struct Target {
        let pid: pid_t
        let bundleID: String?
        let name: String
    }

    private var settings = AppSettings.defaults
    private var isExporting = false

    func apply(_ settings: AppSettings) {
        self.settings = settings
    }

    func exportMarkdown() {
        export { content in
            let panel = NSSavePanel()
            panel.nameFieldStringValue = CheatSheetMarkdown.fileName(appName: content.appName, pathExtension: "md")
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else {
                return
            }
            do {
                try Data(CheatSheetMarkdown.render(content).utf8).write(to: url, options: .atomic)
            } catch {
                // No path or app name in the log.
                Self.log.error("writing the Markdown export failed: \(error.localizedDescription, privacy: .public)")
                NSAlert(error: error).runModal()
            }
        }
    }

    func printSheet() {
        export { content in
            let jobTitle = CheatSheetMarkdown.fileName(appName: content.appName, pathExtension: "pdf")
            CheatSheetDocument.printOperation(for: content, jobTitle: jobTitle).run()
        }
    }

    /// Reads the frontmost app off the main actor, then hands its content to
    /// `finish` with ShortcutLens active, so its panels take focus.
    private func export(_ finish: @escaping (OverlayContent<AXUIElement>) -> Void) {
        guard !isExporting else {
            return
        }
        guard let target = Self.frontmostTarget() else {
            showNoAppAlert()
            return
        }
        isExporting = true
        let settings = settings
        Task { [weak self] in
            let read = await Task.detached(priority: .userInitiated) {
                OverlayController.readContent(
                    pid: target.pid, bundleID: target.bundleID, appName: target.name, settings: settings
                )
            }.value.value
            let content = read.content.appending(
                sectionTitle: SystemHotKeyCatalog.sectionTitle, shortcuts: read.systemShortcuts
            )
            NSApp.activate()
            finish(content)
            self?.isExporting = false
        }
    }

    /// The frontmost app unless it is ShortcutLens itself, e.g. while its
    /// Settings window is in front.
    private static func frontmostTarget() -> Target? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return nil
        }
        return Target(pid: app.processIdentifier, bundleID: app.bundleIdentifier, name: app.localizedName ?? "")
    }

    private func showNoAppAlert() {
        let alert = NSAlert()
        alert.messageText = "No app to export"
        alert.informativeText = "Switch to the app whose shortcuts you want, then choose this again from the menu bar."
        NSApp.activate()
        alert.runModal()
    }
}
