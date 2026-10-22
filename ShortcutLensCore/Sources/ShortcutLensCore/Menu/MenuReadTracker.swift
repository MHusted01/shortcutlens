/// Which background menu reads still count.
///
/// Each request to show an app starts a new generation; a read from an older
/// generation is cached but not shown. A read made with older settings or an
/// older keyboard layout (its system shortcut labels are stale) is neither
/// cached nor shown, and is read again when it was for the latest request.
/// The read running for an app is kept so repeated requests reuse it instead
/// of piling up concurrent menu walks.
public struct MenuReadTracker<Key: Hashable, Read> {
    /// When a read was asked for; compared when it finishes.
    public struct Stamp: Equatable, Sendable {
        let generation: Int
        let layoutEpoch: Int
    }

    /// What happens next with a finished read.
    public enum Next: Equatable, Sendable {
        /// The read is not for the latest request.
        case none
        /// The read is stale and was for the latest request.
        case readAgain
        case show
    }

    /// What to do with a finished read.
    public struct Outcome: Equatable, Sendable {
        public let caches: Bool
        public let next: Next

        public init(caches: Bool, next: Next) {
            self.caches = caches
            self.next = next
        }
    }

    /// The settings new reads use.
    public let settings: AppSettings
    private let generation: Int
    /// Bumped on a keyboard layout switch.
    private let layoutEpoch: Int
    private let inFlight: (key: Key, read: Read)?

    public init(settings: AppSettings) {
        self.init(settings: settings, generation: 0, layoutEpoch: 0, inFlight: nil)
    }

    private init(settings: AppSettings, generation: Int, layoutEpoch: Int, inFlight: (key: Key, read: Read)?) {
        self.settings = settings
        self.generation = generation
        self.layoutEpoch = layoutEpoch
        self.inFlight = inFlight
    }

    /// The stamp for a read asked for now.
    public var stamp: Stamp {
        Stamp(generation: generation, layoutEpoch: layoutEpoch)
    }

    /// A new request; reads asked for before it are no longer shown.
    public func nextGeneration() -> Self {
        copy(generation: generation + 1)
    }

    /// The read already running for `key`, if any.
    public func running(for key: Key) -> Read? {
        inFlight?.key == key ? inFlight?.read : nil
    }

    /// `read` is now the one running for `key`.
    public func started(_ read: Read, for key: Key) -> Self {
        copy(inFlight: .some((key, read)))
    }

    /// New reads use `settings`. Settings that change what a read returns
    /// stop reusing the running read; `dropsCache` is true when the menus
    /// themselves change.
    public func applying(_ settings: AppSettings) -> (tracker: Self, dropsCache: Bool) {
        let restarts = settings.restartsReads(comparedTo: self.settings)
        let tracker = Self(
            settings: settings, generation: generation, layoutEpoch: layoutEpoch, inFlight: restarts ? nil : inFlight
        )
        return (tracker, settings.changesMenuReads(comparedTo: self.settings))
    }

    /// After a keyboard layout switch, reads asked for before it are stale
    /// and the running read is not reused. Nil when no label depends on the
    /// layout, because system shortcuts are off.
    public func changingLayout() -> Self? {
        guard settings.showsSystemShortcuts else {
            return nil
        }
        return Self(settings: settings, generation: generation, layoutEpoch: layoutEpoch + 1, inFlight: nil)
    }

    /// The read for `key` asked for at `stamp` finished; it was made with
    /// `settings`. A read that outlived its app (`appTerminated`) is not
    /// cached, since nothing would remove that entry.
    public func finishing(
        _ key: Key, stamp: Stamp, settings: AppSettings, appTerminated: Bool
    ) -> (tracker: Self, outcome: Outcome) {
        let isCurrent = !self.settings.restartsReads(comparedTo: settings) && stamp.layoutEpoch == layoutEpoch
        let tracker = isCurrent && inFlight?.key == key ? copy(inFlight: .some(nil)) : self
        let next: Next = if stamp.generation != generation {
            .none
        } else {
            isCurrent ? .show : .readAgain
        }
        return (tracker, Outcome(caches: isCurrent && !appTerminated, next: next))
    }

    private func copy(generation: Int? = nil, inFlight: (key: Key, read: Read)?? = nil) -> Self {
        Self(
            settings: settings, generation: generation ?? self.generation, layoutEpoch: layoutEpoch,
            inFlight: inFlight ?? self.inFlight
        )
    }
}

extension MenuReadTracker: Sendable where Key: Sendable, Read: Sendable {}
