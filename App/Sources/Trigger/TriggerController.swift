import AppKit
import os
import ShortcutLensCore

/// Feeds modifier, key and mouse events into `TriggerStateMachine` and runs
/// its timer. The same events go to `DoubleTapDetector`, whose double tap of
/// the chosen `PaletteTrigger` opens the palette.
///
/// Uses `NSEvent` monitors, not a `CGEventTap`: a global monitor sees events
/// sent to other apps (key events only with the Accessibility permission), a
/// local monitor sees events sent to this app. Monitors are installed only
/// while the permission is granted.
///
/// Key presses are the main way a countdown is cancelled (Tab in Cmd+Tab does
/// reach the global monitor). As a best-effort fallback, another app
/// activating or a Space change also counts as an interruption, for changes
/// that arrive without a key event.
///
/// System hotkeys (Cmd+Space, screenshots, input-source switching) never
/// reach the monitors. To catch them, the controller reads the time since the
/// last hardware key press (`CGEventSource`, no extra permission) when the
/// countdown ends and every 0.1 s while the overlay is shown. The palette
/// takes typed keys itself, so it is not polled.
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

    private var machine = TriggerStateMachine.initial
    private var paletteTrigger = PaletteTrigger.command
    private var doubleTap = DoubleTapDetector.initial
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var shownPoll: Timer?

    /// True while Command is held and the overlay may still show.
    var isCountingDown: Bool {
        machine.phase.isCountingDown
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
            handle(.reset)
            doubleTap = DoubleTapDetector(trigger: paletteTrigger)
        }
    }

    /// Seconds Command must be held, from the next countdown on.
    func setDelay(_ delay: TimeInterval) {
        machine = machine.with(delay: delay)
    }

    /// The modifier to double-tap for the palette. A tap in progress is dropped.
    func setPaletteTrigger(_ trigger: PaletteTrigger) {
        guard trigger != paletteTrigger else {
            return
        }
        paletteTrigger = trigger
        doubleTap = DoubleTapDetector(trigger: trigger)
    }

    /// Closes the palette, for example after Escape or running an item.
    /// Does nothing when the palette is not open.
    func closePalette() {
        handle(.close)
    }

    private func installMonitors() {
        // AppKit calls both monitors on the main thread. The global monitor
        // sees only events sent to other apps, so its clicks are outside the panel.
        let deliver: (NSEvent, Bool) -> Void = { [weak self] event, isOutside in
            let triggerEvent = Self.triggerEvent(for: event, isOutside: isOutside)
            let tapEvent = Self.tapEvent(for: event)
            MainActor.assumeIsolated {
                self?.handle(triggerEvent)
                self?.detectDoubleTap(tapEvent)
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
                self?.interrupt()
            }
        }
        let space = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.interrupt()
            }
        }
        observers = [activation, space]
    }

    private func handle(_ event: TriggerStateMachine.Event) {
        let (state, action) = machine.updated(with: event)
        machine = state
        if state.phase != .shown {
            stopShownPoll()
        }
        switch action {
        case let .startTimer(token, delay):
            startTimer(token: token, delay: delay)
            onArm()
        case .cancelTimer:
            cancelTimer()
        case .show:
            startShownPoll()
            onShow()
        case .showPalette:
            onShowPalette()
        case .hide:
            // Event kinds only, never key characters.
            Self.log.notice("hide after \(String(describing: event), privacy: .public)")
            onHide()
        case .none:
            break
        }
    }

    /// Focus moved without a key event the monitors saw; this also breaks a
    /// double tap in progress.
    private func interrupt() {
        handle(.interrupted)
        detectDoubleTap(.otherInput)
    }

    /// Runs after the state machine has seen the same event, so the second
    /// release has already ended the countdown when the double tap arrives.
    /// A double tap with a key press the monitors missed (Cmd+Space twice)
    /// is dropped.
    private func detectDoubleTap(_ event: DoubleTapDetector.Event) {
        let (state, startedAt) = doubleTap.updated(with: event)
        doubleTap = state
        guard let startedAt else {
            return
        }
        guard !Self.keyWentDown(since: MissedKeyDown(armedAt: startedAt)) else {
            Self.log.notice("missed key press during double tap")
            return
        }
        handle(.doubleTap)
    }

    private func startTimer(token: Int, delay: TimeInterval) {
        cancelTimer()
        let watch = MissedKeyDown(armedAt: Self.now())
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                // Re-read the keys in case a release was missed while counting down.
                self?.handle(.modifiersChanged(Self.heldModifiers(NSEvent.modifierFlags)))
                if Self.keyWentDown(since: watch) {
                    Self.log.notice("missed key press during countdown")
                    self?.handle(.keyDown)
                }
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

    /// Hides the overlay when a key goes down that the monitors did not see.
    /// A click may already have hidden the panel; the extra hide is a no-op.
    private func startShownPoll() {
        stopShownPoll()
        let watch = MissedKeyDown(armedAt: Self.now())
        let poll = Timer(timeInterval: Self.shownPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard Self.keyWentDown(since: watch) else {
                    return
                }
                Self.log.notice("missed key press while shown")
                self?.handle(.keyDown)
            }
        }
        RunLoop.main.add(poll, forMode: .common)
        shownPoll = poll
    }

    private func stopShownPoll() {
        shownPoll?.invalidate()
        shownPoll = nil
    }

    /// Seconds on the same clock as the `CGEventSource` reading and
    /// `NSEvent.timestamp`.
    private static func now() -> Double {
        ProcessInfo.processInfo.systemUptime
    }

    private static func keyWentDown(since watch: MissedKeyDown) -> Bool {
        let seconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        return watch.keyWentDown(now: now(), secondsSinceLastKeyDown: seconds)
    }

    private nonisolated static func triggerEvent(for event: NSEvent, isOutside: Bool) -> TriggerStateMachine.Event {
        switch event.type {
        case .flagsChanged:
            .modifiersChanged(heldModifiers(event.modifierFlags))
        case .keyDown:
            .keyDown
        default:
            isOutside ? .mouseDownOutside : .mouseDown
        }
    }

    /// `NSEvent.timestamp` is seconds since system start, a monotonic clock.
    private nonisolated static func tapEvent(for event: NSEvent) -> DoubleTapDetector.Event {
        event.type == .flagsChanged
            ? .modifiersChanged(heldModifiers(event.modifierFlags), time: event.timestamp)
            : .otherInput
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
