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

    /// Keeps the `.md` extension even if the system has no type for it;
    /// `.plainText` would make the save panel switch to `.txt`.
    private static let markdownType = UTType(filenameExtension: "md")
        ?? UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)

    private var settings = AppSettings.defaults
    private var isExporting = false

    func apply(_ settings: AppSettings) {
        self.settings = settings
    }

    func exportMarkdown() {
        export { content in
            let panel = NSSavePanel()
            panel.nameFieldStringValue = CheatSheetMarkdown.fileName(appName: content.appName, pathExtension: "md")
            panel.allowedContentTypes = [Self.markdownType]
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
        guard let target = FrontmostApp.current() else {
            showNoAppAlert()
            return
        }
        isExporting = true
        let settings = settings
        let layout = settings.showsSystemShortcuts ? KeyboardLayout.current() : .none
        Task { [weak self] in
            let read = await Task.detached(priority: .userInitiated) {
                OverlayController.readContent(
                    pid: target.pid, bundleID: target.bundleID, appName: target.name, settings: settings,
                    layout: layout
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

    private func showNoAppAlert() {
        let alert = NSAlert()
        alert.messageText = "No app to export"
        alert.informativeText = "Switch to the app whose shortcuts you want, then choose this again from the menu bar."
        NSApp.activate()
        alert.runModal()
    }
}
