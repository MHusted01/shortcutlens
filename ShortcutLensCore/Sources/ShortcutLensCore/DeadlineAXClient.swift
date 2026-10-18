/// Wraps an `AXClient` with a total time budget for one menu read.
///
/// The per-call messaging timeout alone does not bound a read: a hung app
/// with hundreds of menu items fails each call only after the timeout. Once
/// the budget is spent, every call returns nil or empty without reaching the
/// app, so `MenuReader` unwinds quickly and returns what it read so far.
/// A call that started before the deadline may still run past it.
///
/// Create one client per read; the budget starts at `init`.
public struct DeadlineAXClient<Base: AXClient>: AXClient {
    public typealias Element = Base.Element

    public let base: Base
    /// The time on `now`'s clock after which no more calls are made.
    public let deadline: Double
    private let now: () -> Double

    /// `now` returns seconds on a monotonic clock, such as system uptime.
    public init(base: Base, budget: Double, now: @escaping () -> Double) {
        self.base = base
        self.now = now
        deadline = now() + budget
    }

    /// True once the budget is spent, i.e. a read may be incomplete.
    public var hasExpired: Bool {
        now() >= deadline
    }

    public func menuBar(forProcess pid: Int32) -> Element? {
        hasExpired ? nil : base.menuBar(forProcess: pid)
    }

    public func children(of element: Element) -> [Element] {
        hasExpired ? [] : base.children(of: element)
    }

    public func attributes(of element: Element) -> MenuItemAttributes? {
        hasExpired ? nil : base.attributes(of: element)
    }
}
