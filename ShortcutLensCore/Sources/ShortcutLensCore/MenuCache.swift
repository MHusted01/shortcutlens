/// The last menu content read per app, so the overlay can show it at once
/// while a fresh read runs.
///
/// Entries have no expiry; the caller removes an app's entry when it quits.
/// At most `capacity` entries are kept: storing beyond that drops the entry
/// stored least recently. Reading a value does not count as a use, since every
/// overlay open stores a fresh read anyway.
public struct MenuCache<Key: Hashable, Value> {
    public let capacity: Int
    private let values: [Key: Value]
    /// Keys from least to most recently stored.
    private let order: [Key]

    /// `capacity` values below 1 are raised to 1.
    public init(capacity: Int) {
        self.init(capacity: max(capacity, 1), values: [:], order: [])
    }

    private init(capacity: Int, values: [Key: Value], order: [Key]) {
        self.capacity = capacity
        self.values = values
        self.order = order
    }

    /// The number of cached apps.
    public var count: Int {
        values.count
    }

    public var isEmpty: Bool {
        values.isEmpty
    }

    public func value(for key: Key) -> Value? {
        values[key]
    }

    /// A copy with `value` stored for `key`.
    ///
    /// An incomplete value, such as a read that ran out of time or found
    /// nothing, is only stored when `key` has no value yet; otherwise the
    /// cached one is kept.
    public func storing(_ value: Value, for key: Key, isComplete: Bool = true) -> Self {
        guard isComplete || values[key] == nil else {
            return self
        }
        let kept = order.filter { $0 != key } + [key]
        let dropped = kept.dropLast(capacity)
        var newValues = values
        newValues[key] = value
        dropped.forEach { newValues[$0] = nil }
        return Self(capacity: capacity, values: newValues, order: Array(kept.suffix(capacity)))
    }

    /// A copy without the value for `key`.
    public func removing(_ key: Key) -> Self {
        var newValues = values
        newValues[key] = nil
        return Self(capacity: capacity, values: newValues, order: order.filter { $0 != key })
    }
}
