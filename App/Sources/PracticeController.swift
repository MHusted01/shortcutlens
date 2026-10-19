import AppKit
import Observation
import os
import ShortcutLensCore
import SwiftUI

/// Owns the practice window: reads the frontmost app's menus, asks a session
/// of questions and saves progress after every answer. Progress and
/// favourites stay in `UserDefaults`.
@MainActor
@Observable
final class PracticeController {
    enum State: Equatable {
        case reading
        /// The app has no menu shortcut that can be practised.
        case empty
        case practising
    }

    private static let log = Logger(subsystem: "dev.shortcutlens", category: "practice")

    private(set) var appName = ""
    private(set) var state = State.reading
    private(set) var session = PracticeSession(questions: [])
    /// False for apps without a bundle ID, whose progress cannot be saved.
    private(set) var savesProgress = false
    private(set) var hasProgress = false
    @ObservationIgnored private var target: FrontmostApp?
    @ObservationIgnored private var cards: [PracticeCard] = []
    @ObservationIgnored private var settings = AppSettings.defaults
    /// Counts reads, so only the latest one is shown.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var window: NSWindow?

    func apply(_ settings: AppSettings) {
        self.settings = settings
    }

    /// Practises the frontmost app; called from the menu bar menu.
    func start() {
        guard let target = FrontmostApp.current() else {
            showNoAppAlert()
            return
        }
        self.target = target
        appName = target.name
        savesProgress = target.bundleID != nil
        state = .reading
        generation += 1
        showWindow()
        read(target, generation: generation)
    }

    func answer(_ keys: RecordedKeys) {
        let press = PracticePress(
            keyCode: keys.keyCode, character: keys.key, shiftedCharacter: keys.shiftedKey, modifiers: keys.modifiers
        )
        update(session.answering(press))
    }

    func reveal() {
        update(session.revealing())
    }

    func next() {
        session = session.advancing()
    }

    func practiseAgain() {
        session = PracticeSession(questions: questions())
    }

    func resetProgress() {
        PracticeProgress(store: UserDefaults.standard).resetting(bundleID: target?.bundleID)
            .save(to: UserDefaults.standard)
        hasProgress = false
        practiseAgain()
    }

    func close() {
        window?.close()
    }

    private func read(_ target: FrontmostApp, generation: Int) {
        // System shortcuts are always read: their keys are left out.
        let settings = settings.with(showsSystemShortcuts: true)
        Task { [weak self] in
            let read = await Task.detached(priority: .userInitiated) {
                OverlayController.readContent(
                    pid: target.pid, bundleID: target.bundleID, appName: target.name, settings: settings
                )
            }.value.value
            guard let self, generation == self.generation else {
                return
            }
            cards = PracticeDeck.cards(from: read.content, systemShortcuts: read.systemShortcuts)
            hasProgress = PracticeProgress(store: UserDefaults.standard).hasProgress(bundleID: target.bundleID)
            let count = cards.count
            // A count only, never app names or titles.
            Self.log.notice("practice deck has \(count) cards")
            state = cards.isEmpty ? .empty : .practising
            practiseAgain()
        }
    }

    private func questions() -> [PracticeCard] {
        let bundleID = target?.bundleID
        var random = SystemRandomNumberGenerator()
        return PracticeDeck.questions(
            from: cards,
            progress: PracticeProgress(store: UserDefaults.standard),
            bundleID: bundleID,
            favourites: Favourites(store: UserDefaults.standard).paths(for: bundleID),
            using: &random
        )
    }

    /// Takes `answered` and, when it holds a new answer, saves it at once,
    /// so closing the window mid-session keeps it.
    private func update(_ answered: PracticeSession) {
        guard answered != session else {
            return
        }
        session = answered
        guard let card = answered.current, let correct = answered.outcome, let bundleID = target?.bundleID else {
            return
        }
        PracticeProgress(store: UserDefaults.standard)
            .recording(correct: correct, for: card.menuPath, bundleID: bundleID)
            .save(to: UserDefaults.standard)
        hasProgress = true
    }

    private func showWindow() {
        let window = window ?? makeWindow()
        self.window = window
        window.title = "Practice – \(appName)"
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: PracticeView(practice: self)))
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        return window
    }

    private func showNoAppAlert() {
        let alert = NSAlert()
        alert.messageText = "No app to practise"
        alert.informativeText = """
        Switch to the app whose shortcuts you want to learn, then choose this again from the menu bar.
        """
        NSApp.activate()
        alert.runModal()
    }
}
