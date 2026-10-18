import ShortcutLensCore
import Testing

/// A clock the test moves forward; `SlowAXClient` advances it on every call.
private final class TestClock {
    var time: Double = 0
}

/// Wraps `FakeAXClient` so every call takes one second on `clock`.
private struct SlowAXClient: AXClient {
    let base: FakeAXClient
    let clock: TestClock

    func menuBar(forProcess pid: Int32) -> Int? {
        clock.time += 1
        return base.menuBar(forProcess: pid)
    }

    func children(of element: Int) -> [Int] {
        clock.time += 1
        return base.children(of: element)
    }

    func attributes(of element: Int) -> MenuItemAttributes? {
        clock.time += 1
        return base.attributes(of: element)
    }
}

struct DeadlineAXClientTests {
    private func makeTree() -> (FakeAXClient, file: Int) {
        let base = FakeAXClient()
        base.addTopLevelMenu("Apple")
        let file = base.addTopLevelMenu("File")
        base.addItem("Save", key: "S", to: file)
        base.addItem("Open", key: "O", to: file)
        return (base, file)
    }

    private func client(_ base: FakeAXClient, budget: Double, clock: TestClock) -> DeadlineAXClient<SlowAXClient> {
        DeadlineAXClient(base: SlowAXClient(base: base, clock: clock), budget: budget) { clock.time }
    }

    @Test func passesCallsThroughWithinTheBudget() {
        let (base, file) = makeTree()
        let clock = TestClock()
        let client = client(base, budget: 100, clock: clock)

        #expect(client.menuBar(forProcess: FakeAXClient.pid) == FakeAXClient.menuBar)
        #expect(client.children(of: file) == base.children(of: file))
        #expect(client.attributes(of: file)?.title == "File")
        #expect(!client.hasExpired)
    }

    @Test func makesNoCallsOnceTheBudgetIsSpent() {
        let (base, file) = makeTree()
        let clock = TestClock()
        let client = client(base, budget: 2, clock: clock)
        clock.time = 2
        let readsBefore = base.attributeReads

        #expect(client.menuBar(forProcess: FakeAXClient.pid) == nil)
        #expect(client.children(of: file).isEmpty)
        #expect(client.attributes(of: file) == nil)
        #expect(base.attributeReads == readsBefore)
        #expect(clock.time == 2)
        #expect(client.hasExpired)
    }

    @Test func budgetStartsWhenTheClientIsCreated() {
        let (base, _) = makeTree()
        let clock = TestClock()
        clock.time = 50
        let client = client(base, budget: 2, clock: clock)

        #expect(client.menuBar(forProcess: FakeAXClient.pid) == FakeAXClient.menuBar)
    }

    @Test func readerReturnsWhatWasReadBeforeTheBudgetRanOut() {
        let (base, _) = makeTree()
        let edit = base.addTopLevelMenu("Edit")
        base.addItem("Copy", key: "C", to: edit)
        let clock = TestClock()
        let unlimited = MenuReader(client: client(base, budget: 1000, clock: clock)).read(processID: FakeAXClient.pid)
        let callsForFile = 10

        clock.time = 0
        let limited = client(base, budget: Double(callsForFile), clock: clock)
        let groups = MenuReader(client: limited).read(processID: FakeAXClient.pid)

        #expect(unlimited.map(\.title) == ["File", "Edit"])
        #expect(groups.map(\.title) == ["File"])
        #expect(groups[0].items.map(\.shortcut.title) == ["Save", "Open"])
        #expect(limited.hasExpired)
    }
}
