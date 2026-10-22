import AppKit
import Observation
import os
import ShortcutLensCore
import SwiftUI

/// The menu item whose shortcut is edited, with the overlay content it was
/// chosen from for the conflict check.
struct ShortcutEditRequest {
    let appName: String
    let processID: pid_t
    let bundleID: String?
    let bundleURL: URL?
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

    enum Relaunch: Equatable {
        case idle
        case running
        /// Why the app was not relaunched, shown under the outcome.
        case failed(String)
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
    private(set) var relaunch = Relaunch.idle
    /// Counts relaunches, so only the latest one reports its outcome.
    @ObservationIgnored private var relaunchGeneration = 0
    @ObservationIgnored private var window: NSWindow?

    func show(_ request: ShortcutEditRequest) {
        self.request = request
        recorded = nil
        problem = nil
        conflict = nil
        status = .editing
        relaunch = .idle
        relaunchGeneration += 1
        refreshCustomEntry()
        let window = window ?? makeWindow()
        self.window = window
        window.title = String(localized: "Edit Shortcut – \(request.appName)")
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
            return String(
                localized: "\(request.appName) is sandboxed. macOS does not let ShortcutLens edit its App Shortcuts."
            )
        }
        return request.bundleID == nil ? String(localized: "\(request.appName) has no bundle identifier.") : nil
    }

    /// The recorded keys as menus show them, e.g. `⌥⌘S`.
    var recordedLabel: String? {
        recorded.flatMap { ShortcutFormatter.string(for: Self.shortcut(for: $0)) }.map { KeyDisplay.text(for: $0) }
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
        } ?? .none
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

    /// After a change, while no relaunch runs and the app can be opened again.
    var canRelaunch: Bool {
        [.saved, .removed].contains(status) && relaunch != .running && request?.bundleURL != nil
    }

    /// Quits and reopens the app so it uses the change, then closes the window.
    func relaunchApp() {
        guard canRelaunch, let request, let bundleID = request.bundleID, let bundleURL = request.bundleURL else {
            return
        }
        relaunch = .running
        relaunchGeneration += 1
        let generation = relaunchGeneration
        Task {
            let outcome = await AppRelauncher.relaunch(
                processID: request.processID, bundleID: bundleID, bundleURL: bundleURL
            )
            // The window may show another item by now.
            guard generation == relaunchGeneration, relaunch == .running else {
                return
            }
            finishRelaunch(outcome, appName: request.appName)
        }
    }

    func close() {
        window?.close()
    }

    private func finishRelaunch(_ outcome: AppRelauncher.Outcome, appName: String) {
        switch outcome {
        case .relaunched:
            Self.log.notice("app relaunched")
            relaunch = .idle
            close()
        case .didNotQuit:
            Self.log.error("app did not quit")
            relaunch = .failed(String(localized: "\(appName) did not quit. Quit it yourself and open it again."))
        case .didNotOpen:
            Self.log.error("app did not open")
            relaunch = .failed(String(localized: "\(appName) quit but could not be opened again."))
        }
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
