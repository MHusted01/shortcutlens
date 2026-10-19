import AppKit
import Observation
import os
import ServiceManagement
import ShortcutLensCore
import SwiftUI

/// Owns the user's settings and the settings window.
///
/// Settings live in `UserDefaults` and apply at once through `onChange`.
/// Launch at login is read from and written to `SMAppService` directly, so the
/// toggle always shows what the system will actually do.
@MainActor
@Observable
final class SettingsController {
    private static let log = Logger(subsystem: "dev.shortcutlens", category: "settings")

    private(set) var settings: AppSettings
    private(set) var launchAtLogin: SMAppService.Status = .notRegistered
    /// The last launch-at-login failure, shown in the window until the next attempt.
    private(set) var launchAtLoginError: String?
    /// The shortcut packs as last read, for listing problems per file.
    private(set) var packs = PackLibrary.empty
    /// Why the packs folder could not be created, if it failed.
    private(set) var packsFolderError: String?
    /// Counts reloads, so only the latest one is shown.
    @ObservationIgnored private var packsGeneration = 0
    /// Called with the new settings after every change.
    @ObservationIgnored var onChange: (AppSettings) -> Void = { _ in }
    @ObservationIgnored private let store: UserDefaults
    @ObservationIgnored private var window: NSWindow?

    init(store: UserDefaults = .standard) {
        self.store = store
        settings = AppSettings(store: store)
    }

    func update(_ newSettings: AppSettings) {
        guard newSettings != settings else {
            return
        }
        settings = newSettings
        newSettings.save(to: store)
        onChange(newSettings)
    }

    func showWindow() {
        refreshLaunchAtLogin()
        reloadPacks()
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            launchAtLoginError = nil
        } catch {
            Self.log.error("launch at login change failed: \(error.localizedDescription, privacy: .public)")
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Reads the pack files again, off the main actor. The overlay reads them
    /// on its own with every menu read; this only updates what the window
    /// lists. A slower earlier reload cannot overwrite a later one.
    func reloadPacks() {
        packsGeneration += 1
        let generation = packsGeneration
        Task {
            let library = await Task.detached(priority: .userInitiated) { PackSource.library() }.value
            guard generation == packsGeneration else {
                return
            }
            packs = library
        }
    }

    /// Opens the user's packs folder in Finder, creating it first.
    func showPacksFolder() {
        do {
            try PackSource.createUserDirectory()
            packsFolderError = nil
            NSWorkspace.shared.open(PackSource.userDirectory)
        } catch {
            Self.log.error("packs folder not created: \(error.localizedDescription, privacy: .public)")
            packsFolderError = error.localizedDescription
        }
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status
    }

    private func makeWindow() -> NSWindow {
        // The title follows the selected tab.
        let window = NSWindow(contentViewController: SettingsTabController(controller: self, store: store))
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        return window
    }
}
