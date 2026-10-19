import ShortcutLensCore
import Testing

struct ContainerReadsTests {
    private let container = UserKeyEquivalent.parse(["Show Fonts": "@$t"])
    private let fallback = UserKeyEquivalent.parse(["Other": "@o"])

    @Test func readsEveryAppUntilOneIsDenied() {
        let reads = ContainerReads()

        #expect(reads.shouldRead(bundleID: "com.apple.TextEdit"))
        #expect(reads.recording(.unavailable, for: "com.apple.TextEdit").shouldRead(bundleID: "com.apple.TextEdit"))
        #expect(reads.recording(.read([]), for: "com.apple.TextEdit").shouldRead(bundleID: "com.apple.TextEdit"))
    }

    @Test func skipsAnAppAfterADenial() {
        let reads = ContainerReads().recording(.denied, for: "com.apple.TextEdit")

        #expect(!reads.shouldRead(bundleID: "com.apple.TextEdit"))
        #expect(reads.shouldRead(bundleID: "com.apple.Preview"))
    }

    @Test func recordingDoesNotChangeTheOriginal() {
        let reads = ContainerReads()

        _ = reads.recording(.denied, for: "com.apple.TextEdit")

        #expect(reads.shouldRead(bundleID: "com.apple.TextEdit"))
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
