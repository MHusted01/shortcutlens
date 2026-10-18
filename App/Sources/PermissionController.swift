import AppKit
import ApplicationServices
import Observation
import ShortcutLensCore
import SwiftUI

/// Watches the Accessibility permission and drives the onboarding window.
///
/// Uses `AXIsProcessTrusted`, which never shows the system prompt; the
/// onboarding window is the only place the permission is asked for. macOS posts
/// no public notification when the permission changes, so it is polled while
/// missing and polling stops once it is granted.
@MainActor
@Observable
final class PermissionController {
    static let pollInterval: TimeInterval = 1
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    private(set) var permission = AccessibilityPermission.initial
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var window: NSWindow?

    func start() {
        check()
    }

    func showOnboarding() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func closeOnboarding() {
        window?.close()
    }

    private func openSettings() {
        guard let url = Self.settingsURL else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func check() {
        let (state, action) = permission.updated(isTrusted: AXIsProcessTrusted())
        if state != permission {
            permission = state
        }
        switch action {
        case .showOnboarding:
            showOnboarding()
        case .closeOnboarding:
            closeOnboarding()
        case .none:
            break
        }
        updatePolling()
    }

    private func updatePolling() {
        if permission.isGranted {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.check()
                }
            }
        }
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(
            openSettings: { [weak self] in self?.openSettings() },
            later: { [weak self] in self?.closeOnboarding() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "ShortcutLens"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        return window
    }
}
