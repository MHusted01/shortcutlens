import ShortcutLensCore
import Testing

struct ContainerReadsTests {
    private let container = UserKeyEquivalent.parse(["Show Fonts": "@$t"])
    private let fallback = UserKeyEquivalent.parse(["Other": "@o"])

    @Test func readsEveryAppUntilOneIsDenied() {
        let reads = ContainerReads()

        #expect(reads.shouldRead(bundleID: "com.apple.TextEdit"))
        let unavailable = reads.recording(.unavailable, for: "com.apple.TextEdit", generation: reads.generation)
        let read = reads.recording(.read([]), for: "com.apple.TextEdit", generation: reads.generation)

        #expect(unavailable.shouldRead(bundleID: "com.apple.TextEdit"))
        #expect(read.shouldRead(bundleID: "com.apple.TextEdit"))
    }

    @Test func skipsAnAppAfterADenial() {
        let reads = ContainerReads().recording(.denied, for: "com.apple.TextEdit", generation: 0)

        #expect(!reads.shouldRead(bundleID: "com.apple.TextEdit"))
        #expect(reads.shouldRead(bundleID: "com.apple.Preview"))
    }

    @Test func recordingDoesNotChangeTheOriginal() {
        let reads = ContainerReads()

        _ = reads.recording(.denied, for: "com.apple.TextEdit", generation: reads.generation)

        #expect(reads.shouldRead(bundleID: "com.apple.TextEdit"))
    }

    @Test func forgettingDenialsReadsEveryAppAgain() {
        let reads = ContainerReads().recording(.denied, for: "com.apple.TextEdit", generation: 0).forgettingDenials()

        #expect(reads.shouldRead(bundleID: "com.apple.TextEdit"))
    }

    /// A read that started before the denials were forgotten must not block
    /// the app again in the fresh state.
    @Test func ignoresADenialFromAReadStartedBeforeForgetting() {
        let before = ContainerReads()
        let generation = before.generation

        let reads = before.forgettingDenials().recording(.denied, for: "com.apple.TextEdit", generation: generation)

        #expect(reads.shouldRead(bundleID: "com.apple.TextEdit"))
    }

    @Test func recordsADenialFromTheCurrentGeneration() {
        let reads = ContainerReads().forgettingDenials()

        let denied = reads.recording(.denied, for: "com.apple.TextEdit", generation: reads.generation)

        #expect(!denied.shouldRead(bundleID: "com.apple.TextEdit"))
    }

    @Test func usesTheContainerEntriesWhenRead() {
        let entries = ContainerReads.appEntries(.read(container)) { fallback }

        #expect(!container.isEmpty)
        #expect(entries == container)
    }

    /// An empty, valid container file means the app has none; the plain read
    /// would only show entries the app does not use.
    @Test func keepsAnEmptyContainerRead() {
        #expect(ContainerReads.appEntries(.read([])) { fallback } == [])
    }

    @Test(arguments: [ContainerReads.Outcome?.none, .denied, .unavailable])
    func fallsBackWhenTheContainerWasNotRead(outcome: ContainerReads.Outcome?) {
        #expect(!fallback.isEmpty)
        #expect(ContainerReads.appEntries(outcome) { fallback } == fallback)
    }
}
