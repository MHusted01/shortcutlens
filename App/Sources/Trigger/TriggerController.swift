import AppKit
import os
import ShortcutLensCore

/// Connects event monitors, timers and workspace notifications to
/// `TriggerCoordinator`, which makes every trigger decision, and carries out
/// its effects.
///
/// Uses `NSEvent` monitors, not a `CGEventTap`: a global monitor sees events
/// sent to other apps (key events only with the Accessibility permission), a
/// local monitor sees events sent to this app. Monitors are installed only
/// while the permission is granted.
///
/// Key presses are the main way a countdown is cancelled (Tab in Cmd+Tab does
/// reach the global monitor). As a best-effort fallback, another app
/// activating or a Space change also counts as an interruption, for changes
/// that arrive without a key event. System hotkeys never reach the monitors;
/// every input carries a `KeyClock` reading (`CGEventSource`, no extra
/// permission) so the coordinator can spot them.
///
/// Lives as long as the app (owned by `AppDelegate`); call `setEnabled(false)`
/// before dropping it, or the monitors stay installed.
@MainActor
final class TriggerController {
    private static let log = Logger(subsystem: "dev.shortcutlens", category: "trigger")
    private static let monitoredEvents: NSEvent.EventTypeMask = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]
    /// Seconds between checks for missed key presses while the overlay is shown.
    private static let shownPollInterval: TimeInterval = 0.1

    /// Called when a countdown starts, so the overlay can read the menus
    /// before it is shown. The countdown may still be cancelled.
    var onArm: () -> Void = {}
    /// Called when the overlay should appear or disappear.
    var onShow: () -> Void = { TriggerController.log.notice("show overlay") }
    var onHide: () -> Void = { TriggerController.log.notice("hide overlay") }
    /// Called when a double tap of the palette trigger opens the palette.
    var onShowPalette: () -> Void = { TriggerController.log.notice("show palette") }

    private var coordinator = TriggerCoordinator.initial
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var shownPoll: Timer?

    /// True while Command is held and the overlay may still show.
    var isCountingDown: Bool {
        coordinator.isCountingDown
    }

    /// Installs or removes the event monitors.
    func setEnabled(_ enabled: Bool) {
        if enabled, monitors.isEmpty {
            installMonitors()
            observeInterruptions()
            let count = monitors.count
            Self.log.notice("monitors installed: \(count)")
        } else if !enabled, !monitors.isEmpty {
            Self.log.notice("monitors removed")
            monitors.forEach(NSEvent.removeMonitor)
            monitors = []
            observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
            observers = []
            send(.reset)
        }
    }

    /// Seconds Command must be held, from the next countdown on.
    func setDelay(_ delay: TimeInterval) {
        coordinator = coordinator.with(delay: delay)
    }

    /// The modifier to double-tap for the palette.
    func setPaletteTrigger(_ trigger: PaletteTrigger) {
        coordinator = coordinator.with(paletteTrigger: trigger)
    }

    /// Closes the palette, for example after Escape or running an item.
    /// Does nothing when the palette is not open.
    func closePalette() {
        send(.closePalette)
    }

    private func installMonitors() {
        // AppKit calls both monitors on the main thread. The global monitor
        // sees only events sent to other apps, so its clicks are outside the panel.
        let deliver: (NSEvent, Bool) -> Void = { [weak self] event, isOutside in
            let input = Self.input(for: event, isOutside: isOutside)
            MainActor.assumeIsolated {
                self?.send(input)
            }
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.monitoredEvents) { event in
            deliver(event, true)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.monitoredEvents) { event in
            deliver(event, false)
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    private func observeInterruptions() {
        let center = NSWorkspace.shared.notificationCenter
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let activation = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            // The overlay itself may activate this app; that is not an interruption.
            guard app?.processIdentifier != ownPID else {
                return
            }
            MainActor.assumeIsolated {
                self?.send(.interrupted)
            }
        }
        let space = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.send(.interrupted)
            }
        }
        observers = [activation, space]
    }

    private func send(_ input: TriggerCoordinator.Input) {
        let (state, effects) = coordinator.updated(with: input, clock: Self.clock())
        coordinator = state
        effects.forEach(perform)
    }

    private func perform(_ effect: TriggerCoordinator.Effect) {
        switch effect {
        case let .startCountdown(token, delay):
            startTimer(token: token, delay: delay)
            onArm()
        case .cancelCountdown:
            cancelTimer()
        case .startShownPoll:
            startShownPoll()
        case .stopShownPoll:
            stopShownPoll()
        case .show:
            onShow()
        case .showPalette:
            onShowPalette()
        case let .hide(event):
            // Event kinds only, never key characters.
            Self.log.notice("hide after \(String(describing: event), privacy: .public)")
            onHide()
        case let .missedKeyPress(moment):
            Self.log.notice("missed key press during \(moment.rawValue, privacy: .public)")
        }
    }

    private func startTimer(token: Int, delay: TimeInterval) {
        cancelTimer()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                let held = HeldModifiers(eventFlags: NSEvent.modifierFlags.rawValue)
                self?.send(.countdownEnded(token: token, held: held))
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

    private func startShownPoll() {
        stopShownPoll()
        let poll = Timer(timeInterval: Self.shownPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.send(.shownPollTick)
            }
        }
        RunLoop.main.add(poll, forMode: .common)
        shownPoll = poll
    }

    private func stopShownPoll() {
        shownPoll?.invalidate()
        shownPoll = nil
    }

    /// System uptime is the clock of both the `CGEventSource` reading and
    /// `NSEvent.timestamp`.
    private static func clock() -> KeyClock {
        let seconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        return KeyClock(now: ProcessInfo.processInfo.systemUptime, secondsSinceLastKeyDown: seconds)
    }

    private nonisolated static func input(for event: NSEvent, isOutside: Bool) -> TriggerCoordinator.Input {
        switch event.type {
        case .flagsChanged:
            .modifiersChanged(HeldModifiers(eventFlags: event.modifierFlags.rawValue), time: event.timestamp)
        case .keyDown:
            .keyDown
        default:
            .mouseDown(outside: isOutside)
        }
    }
}
