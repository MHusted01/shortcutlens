import AppKit
import ApplicationServices
import Observation
import ShortcutLensCore
import SwiftUI

/// Watches the Accessibility permission and drives the onboarding window,
/// which shows the permission's live status on its last step.
///
/// Uses `AXIsProcessTrusted`, which never shows the system prompt; the
/// onboarding window is the only place the permission is asked for. macOS posts
/// no public notification when the permission changes, so it is polled for the
/// whole session: often while missing, less often once granted so a later
/// revocation is still noticed.
@MainActor
@Observable
final class PermissionController {
    static let missingPollInterval: TimeInterval = 1
    static let grantedPollInterval: TimeInterval = 5
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    private(set) var permission = AccessibilityPermission.initial
    /// Called after every check that changed `permission`.
    @ObservationIgnored var onChange: (AccessibilityPermission) -> Void = { _ in }
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var window: NSWindow?
    @ObservationIgnored private let onboarding = OnboardingModel()

    func start() {
        check()
    }

    /// Opens onboarding on `step`; the window is centred only the first time.
    func showOnboarding(at step: OnboardingStep = .welcome) {
        onboarding.step = step
        if window == nil {
            let window = makeWindow()
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func closeOnboarding() {
        window?.close()
    }

    /// Tells VoiceOver users on the onboarding window that the permission arrived.
    private func announceGrant() {
        guard window?.isVisible == true, NSWorkspace.shared.isVoiceOverEnabled else {
            return
        }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: OnboardingText.grantedAnnouncement,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
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
            let wasGranted = permission.isGranted
            permission = state
            onboarding.isGranted = state.isGranted
            onChange(state)
            if state.isGranted, !wasGranted {
                announceGrant()
            }
        }
        if action == .showOnboarding {
            showOnboarding()
        }
        updatePolling()
    }

    private func updatePolling() {
        let interval = permission.isGranted ? Self.grantedPollInterval : Self.missingPollInterval
        guard timer?.timeInterval != interval else {
            return
        }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.check()
            }
        }
        // `.common` keeps the timer firing while the menu bar menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(
            model: onboarding,
            openSettings: { [weak self] in self?.openSettings() },
            close: { [weak self] in self?.closeOnboarding() }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "ShortcutLens"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        // The final size before the window is centred, so it is centred on that.
        window.setContentSize(hosting.view.fittingSize)
        return window
    }
}
