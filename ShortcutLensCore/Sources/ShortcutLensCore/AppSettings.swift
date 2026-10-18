import Foundation

/// Where `AppSettings` are kept: `UserDefaults` in the app, a dictionary in tests.
public protocol SettingsStore {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

/// `UserDefaults` already has both methods.
extension UserDefaults: SettingsStore {}

/// The user's settings. Every value is clamped to its range, so a hand-edited
/// or outdated store cannot produce a delay or depth the app cannot handle.
///
/// Launch at login is not part of this: `SMAppService` owns that state.
public struct AppSettings: Equatable, Sendable {
    /// The store keys.
    public enum Key {
        public static let triggerDelay = "triggerDelay"
        public static let maxMenuDepth = "maxMenuDepth"
        public static let showsDisabledItems = "showsDisabledItems"
        public static let showsSystemShortcuts = "showsSystemShortcuts"
    }

    public static let triggerDelayRange: ClosedRange<Double> = 0.1 ... 1.5
    /// The trigger delay moves in steps of 0.05 s.
    public static let triggerDelayStep = 0.05
    /// The upper bound is `MenuReader.defaultMaxDepth`.
    public static let maxMenuDepthRange: ClosedRange<Int> = 1 ... 8

    public static let defaults = Self()

    /// Seconds Command must be held before the overlay shows.
    public let triggerDelay: Double
    /// How many menu levels are read; see `MenuReader.maxDepth`.
    public let maxMenuDepth: Int
    /// Whether disabled menu items are listed (dimmed, not runnable).
    public let showsDisabledItems: Bool
    /// Whether the overlay ends with a "System" section of macOS shortcuts.
    public let showsSystemShortcuts: Bool

    /// Out-of-range values are clamped; a non-finite delay becomes the default.
    public init(
        triggerDelay: Double = TriggerStateMachine.defaultDelay,
        maxMenuDepth: Int = Self.maxMenuDepthRange.upperBound,
        showsDisabledItems: Bool = false,
        showsSystemShortcuts: Bool = true
    ) {
        self.triggerDelay = Self.clampedDelay(triggerDelay)
        self.maxMenuDepth = maxMenuDepth.clamped(to: Self.maxMenuDepthRange)
        self.showsDisabledItems = showsDisabledItems
        self.showsSystemShortcuts = showsSystemShortcuts
    }

    /// The settings in `store`; missing values or values of the wrong type
    /// fall back to the defaults.
    public init(store: SettingsStore) {
        self.init(
            triggerDelay: store.object(forKey: Key.triggerDelay) as? Double ?? Self.defaults.triggerDelay,
            maxMenuDepth: store.object(forKey: Key.maxMenuDepth) as? Int ?? Self.defaults.maxMenuDepth,
            showsDisabledItems: store.object(forKey: Key.showsDisabledItems) as? Bool
                ?? Self.defaults.showsDisabledItems,
            showsSystemShortcuts: store.object(forKey: Key.showsSystemShortcuts) as? Bool
                ?? Self.defaults.showsSystemShortcuts
        )
    }

    public func save(to store: SettingsStore) {
        store.set(triggerDelay, forKey: Key.triggerDelay)
        store.set(maxMenuDepth, forKey: Key.maxMenuDepth)
        store.set(showsDisabledItems, forKey: Key.showsDisabledItems)
        store.set(showsSystemShortcuts, forKey: Key.showsSystemShortcuts)
    }

    public func with(triggerDelay: Double) -> Self {
        copy(triggerDelay: triggerDelay)
    }

    public func with(maxMenuDepth: Int) -> Self {
        copy(maxMenuDepth: maxMenuDepth)
    }

    public func with(showsDisabledItems: Bool) -> Self {
        copy(showsDisabledItems: showsDisabledItems)
    }

    public func with(showsSystemShortcuts: Bool) -> Self {
        copy(showsSystemShortcuts: showsSystemShortcuts)
    }

    private func copy(
        triggerDelay: Double? = nil,
        maxMenuDepth: Int? = nil,
        showsDisabledItems: Bool? = nil,
        showsSystemShortcuts: Bool? = nil
    ) -> Self {
        Self(
            triggerDelay: triggerDelay ?? self.triggerDelay,
            maxMenuDepth: maxMenuDepth ?? self.maxMenuDepth,
            showsDisabledItems: showsDisabledItems ?? self.showsDisabledItems,
            showsSystemShortcuts: showsSystemShortcuts ?? self.showsSystemShortcuts
        )
    }

    /// True when a menu read with these settings can differ from one with
    /// `other`, so cached menu content must be dropped. System shortcuts are
    /// not part of a read; they are added when the overlay shows.
    public func changesMenuReads(comparedTo other: Self) -> Bool {
        maxMenuDepth != other.maxMenuDepth || showsDisabledItems != other.showsDisabledItems
    }

    /// Rounds to whole steps by dividing integers, so 0.55 compares equal to
    /// the literal `0.55`.
    private static func clampedDelay(_ delay: Double) -> Double {
        guard delay.isFinite else {
            return TriggerStateMachine.defaultDelay
        }
        let stepsPerSecond = (1 / triggerDelayStep).rounded()
        return ((delay * stepsPerSecond).rounded() / stepsPerSecond).clamped(to: triggerDelayRange)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
