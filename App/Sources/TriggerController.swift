import AppKit
import os
import ShortcutLensCore

/// Feeds modifier, key and mouse events into `TriggerStateMachine` and runs
/// its timer.
///
/// Uses `NSEvent` monitors, not a `CGEventTap`: a global monitor sees events
/// sent to other apps (key events only with the Accessibility permission), a
/// local monitor sees events sent to this app. Monitors are installed only
/// while the permission is granted.
@MainActor
final class TriggerController {
    private static let log = Logger(subsystem: "dev.shortcutlens", category: "trigger")
    private static let monitoredEvents: NSEvent.EventTypeMask = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]

    /// Called when the overlay should appear or disappear.
    var onShow: () -> Void = { TriggerController.log.notice("show overlay") }
    var onHide: () -> Void = { TriggerController.log.notice("hide overlay") }

    private var machine = TriggerStateMachine.initial
    private var monitors: [Any] = []
    private var timer: Timer?

    /// Installs or removes the event monitors.
    func setEnabled(_ enabled: Bool) {
        if enabled, monitors.isEmpty {
            installMonitors()
            let count = monitors.count
            Self.log.notice("monitors installed: \(count)")
        } else if !enabled, !monitors.isEmpty {
            Self.log.notice("monitors removed")
            monitors.forEach(NSEvent.removeMonitor)
            monitors = []
            handle(.reset)
        }
    }

    private func installMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.monitoredEvents) { [weak self] event in
            let triggerEvent = Self.triggerEvent(for: event)
            MainActor.assumeIsolated {
                self?.handle(triggerEvent)
            }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.monitoredEvents) { [weak self] event in
            let triggerEvent = Self.triggerEvent(for: event)
            MainActor.assumeIsolated {
                self?.handle(triggerEvent)
            }
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    private func handle(_ event: TriggerStateMachine.Event) {
        let (state, action) = machine.updated(with: event)
        machine = state
        switch action {
        case let .startTimer(token, delay):
            startTimer(token: token, delay: delay)
        case .cancelTimer:
            cancelTimer()
        case .show:
            onShow()
        case .hide:
            // Event kinds only, never key characters.
            Self.log.notice("hide after \(String(describing: event), privacy: .public)")
            onHide()
        case .none:
            break
        }
    }

    private func startTimer(token: Int, delay: TimeInterval) {
        cancelTimer()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handle(.timerFired(token: token))
            }
        }
        // `.common` keeps the timer firing while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    private nonisolated static func triggerEvent(for event: NSEvent) -> TriggerStateMachine.Event {
        switch event.type {
        case .flagsChanged:
            .modifiersChanged(heldModifiers(event.modifierFlags))
        case .keyDown:
            .keyDown
        default:
            .mouseDown
        }
    }

    private nonisolated static func heldModifiers(_ flags: NSEvent.ModifierFlags) -> HeldModifiers {
        let pairs: [(NSEvent.ModifierFlags, HeldModifiers)] = [
            (.command, .command), (.shift, .shift), (.option, .option), (.control, .control),
        ]
        return pairs.reduce(into: HeldModifiers()) { held, pair in
            if flags.contains(pair.0) {
                held.insert(pair.1)
            }
        }
    }
}
