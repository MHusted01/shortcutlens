import AppKit
import Observation
import os
import ShortcutLensCore
import SwiftUI

/// The menu item whose shortcut is edited, with the overlay content it was
/// chosen from for the conflict check.
struct ShortcutEditRequest {
    let appName: String
    let bundleID: String?
    let isSandboxed: Bool
    let title: String
    let menuPath: [String]
    /// The item's keys as the overlay shows them, e.g. `⌘S`.
    let currentKeys: String
    let row: RowID
    let content: OverlayContent<AXUIElement>
}

/// Owns the edit window: records keys, checks them, and writes or removes the
/// item's App Shortcut. The app applies the change when it next launches.
@MainActor
@Observable
final class ShortcutEditor {
    enum Status: Equatable {
        case editing
        case saved
        case removed
        case failed
    }

    private static let log = Logger(subsystem: "dev.shortcutlens", category: "editor")

    private(set) var request: ShortcutEditRequest?
    private(set) var recorded: RecordedKeys?
    private(set) var problem: ShortcutRecording.Problem?
    /// "Also used by …" for the recorded keys; saving then says Save Anyway.
    private(set) var conflict: String?
    private(set) var status = Status.editing
    /// Whether the app's own preferences have an entry to remove.
    private(set) var hasCustomEntry = false
    @ObservationIgnored private var window: NSWindow?

    func show(_ request: ShortcutEditRequest) {
        self.request = request
        recorded = nil
        problem = nil
        conflict = nil
        status = .editing
        refreshCustomEntry()
        let window = window ?? makeWindow()
        self.window = window
        window.title = "Edit Shortcut – \(request.appName)"
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    /// Why the item cannot be edited, or nil.
    var unavailableReason: String? {
        guard let request else {
            return nil
        }
        if request.isSandboxed {
            return "\(request.appName) is sandboxed. Editing its App Shortcuts is not supported yet."
        }
        return request.bundleID == nil ? "\(request.appName) has no bundle identifier." : nil
    }

    /// The recorded keys as menus show them, e.g. `⌥⌘S`.
    var recordedLabel: String? {
        recorded.flatMap { ShortcutFormatter.string(for: Self.shortcut(for: $0)) }
    }

    var canSave: Bool {
        recorded != nil && problem == nil && unavailableReason == nil && status == .editing
    }

    func record(_ keys: RecordedKeys) {
        guard let request, status == .editing else {
            return
        }
        recorded = keys
        problem = ShortcutRecording.problem(key: keys.key, modifiers: keys.modifiers)
        let combo = problem == nil ? KeyCombo(Self.shortcut(for: keys)) : nil
        let clashes = combo.map {
            request.content.clashes(with: $0, excludingSection: request.row.section, row: request.row.row)
        } ?? []
        conflict = ShortcutConflicts.explanation(for: clashes)
    }

    func save() {
        guard canSave, let request, let bundleID = request.bundleID, let recorded,
              let entry = UserKeyEquivalent(
                  menuPath: request.menuPath,
                  key: recorded.key,
                  modifiers: recorded.modifiers
              )
        else {
            return
        }
        status = apply { try UserKeyEquivalentWriter.set(entry, bundleID: bundleID) } ? .saved : .failed
    }

    func removeCustomShortcut() {
        guard let request, let bundleID = request.bundleID, status == .editing else {
            return
        }
        status = apply { try UserKeyEquivalentWriter.remove(menuPath: request.menuPath, bundleID: bundleID) }
            ? .removed : .failed
    }

    func close() {
        window?.close()
    }

    /// Runs one write; false when it failed.
    private func apply(_ change: () throws -> Void) -> Bool {
        do {
            try change()
            refreshCustomEntry()
            // A fixed message only, never the app or the menu title.
            Self.log.notice("app shortcut changed")
            return true
        } catch {
            Self.log.error("app shortcut not changed")
            return false
        }
    }

    private func refreshCustomEntry() {
        guard let request, let bundleID = request.bundleID, !request.isSandboxed else {
            hasCustomEntry = false
            return
        }
        hasCustomEntry = UserKeyEquivalentWriter.hasEntry(menuPath: request.menuPath, bundleID: bundleID)
    }

    private static func shortcut(for keys: RecordedKeys) -> MenuShortcut {
        MenuShortcut(title: "", keyCharacter: keys.key, modifiers: keys.modifiers)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: ShortcutEditorView(editor: self)))
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        return window
    }
}
