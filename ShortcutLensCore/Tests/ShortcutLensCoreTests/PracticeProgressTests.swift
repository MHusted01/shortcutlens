import Foundation
import ShortcutLensCore
import Testing

/// A `SettingsStore` backed by a dictionary.
private final class MemoryStore: SettingsStore {
    var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }
}

struct PracticeProgressTests {
    private let save = ["File", "Save"]
    private let open = ["File", "Open…"]

    @Test func startsWithNothingAsked() {
        #expect(PracticeProgress.empty.box(for: save, bundleID: "app") == nil)
        #expect(!PracticeProgress.empty.hasProgress(bundleID: "app"))
    }

    @Test func aRightAnswerMovesUpOneBox() {
        let progress = PracticeProgress.empty
            .recording(correct: true, for: save, bundleID: "app")
            .recording(correct: true, for: save, bundleID: "app")

        #expect(progress.box(for: save, bundleID: "app") == 3)
        #expect(progress.hasProgress(bundleID: "app"))
    }

    @Test func theFirstAnswerStartsInBoxOneOrTwo() {
        let right = PracticeProgress.empty.recording(correct: true, for: save, bundleID: "app")
        let wrong = PracticeProgress.empty.recording(correct: false, for: save, bundleID: "app")

        #expect(right.box(for: save, bundleID: "app") == 2)
        #expect(wrong.box(for: save, bundleID: "app") == 1)
    }

    @Test func stopsAtTheLastBox() {
        let progress = (0 ..< 10).reduce(PracticeProgress.empty) { progress, _ in
            progress.recording(correct: true, for: save, bundleID: "app")
        }

        #expect(progress.box(for: save, bundleID: "app") == PracticeProgress.boxes.upperBound)
    }

    @Test func aWrongAnswerGoesBackToTheFirstBox() {
        let progress = PracticeProgress.empty
            .recording(correct: true, for: save, bundleID: "app")
            .recording(correct: true, for: save, bundleID: "app")
            .recording(correct: false, for: save, bundleID: "app")

        #expect(progress.box(for: save, bundleID: "app") == 1)
    }

    @Test func recordingDoesNotChangeTheOriginal() {
        let original = PracticeProgress.empty.recording(correct: true, for: save, bundleID: "app")

        _ = original.recording(correct: true, for: save, bundleID: "app")

        #expect(original.box(for: save, bundleID: "app") == 2)
    }

    @Test func keepsAppsAndPathsApart() {
        let progress = PracticeProgress.empty.recording(correct: true, for: save, bundleID: "one")

        #expect(progress.box(for: save, bundleID: "two") == nil)
        #expect(progress.box(for: open, bundleID: "one") == nil)
    }

    @Test func pathsThatJoinAlikeStayApart() {
        let progress = PracticeProgress.empty.recording(correct: true, for: ["A B", "C"], bundleID: "app")

        #expect(progress.box(for: ["A", "B C"], bundleID: "app") == nil)
    }

    @Test func ignoresAppsWithoutABundleIDAndEmptyPaths() {
        let progress = PracticeProgress.empty
            .recording(correct: true, for: save, bundleID: nil)
            .recording(correct: true, for: [], bundleID: "app")

        #expect(progress == PracticeProgress.empty)
        #expect(progress.box(for: save, bundleID: nil) == nil)
    }

    @Test func resettingClearsOneApp() {
        let progress = PracticeProgress.empty
            .recording(correct: true, for: save, bundleID: "one")
            .recording(correct: true, for: save, bundleID: "two")
            .resetting(bundleID: "one")

        #expect(!progress.hasProgress(bundleID: "one"))
        #expect(progress.box(for: save, bundleID: "two") == 2)
        #expect(progress.resetting(bundleID: nil) == progress)
    }

    @Test func roundTripsThroughTheStore() {
        let store = MemoryStore()
        let progress = PracticeProgress.empty
            .recording(correct: true, for: save, bundleID: "app")
            .recording(correct: false, for: open, bundleID: "app")

        progress.save(to: store)

        #expect(PracticeProgress(store: store) == progress)
        #expect(store.values[PracticeProgress.storeKey] != nil)
    }

    @Test func aMissingOrWrongValueLoadsAsEmpty() {
        let store = MemoryStore()
        #expect(PracticeProgress(store: store) == PracticeProgress.empty)

        store.values[PracticeProgress.storeKey] = "nonsense"
        #expect(PracticeProgress(store: store) == PracticeProgress.empty)
    }

    @Test func skipsMalformedEntries() {
        let store = MemoryStore()
        store.values[PracticeProgress.storeKey] = [
            "app": [
                ["path": save, "box": 3],
                ["path": open, "box": 9],
                ["path": [String](), "box": 2],
                ["path": "File", "box": 2],
                ["path": ["Edit", "Copy"]],
                "nonsense",
            ] as [Any],
            "other": "nonsense",
            "empty": [Any](),
        ]

        let progress = PracticeProgress(store: store)

        #expect(progress.box(for: save, bundleID: "app") == 3)
        #expect(progress.box(for: open, bundleID: "app") == nil)
        #expect(progress.box(for: ["Edit", "Copy"], bundleID: "app") == nil)
        #expect(!progress.hasProgress(bundleID: "other"))
        #expect(!progress.hasProgress(bundleID: "empty"))
    }

    @Test func aDuplicatePathKeepsItsFirstBox() {
        let store = MemoryStore()
        store.values[PracticeProgress.storeKey] = [
            "app": [["path": save, "box": 4], ["path": save, "box": 1]],
        ]

        #expect(PracticeProgress(store: store).box(for: save, bundleID: "app") == 4)
    }
}
