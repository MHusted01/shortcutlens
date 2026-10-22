import os

/// The "overlay" log category, and signpost intervals for the steps between
/// holding Command and seeing the overlay, shown in Instruments under it.
/// Counts and timing only, never app names or titles.
enum OverlayLog {
    static let logger = Logger(subsystem: "dev.shortcutlens", category: "overlay")
    static let signposter = OSSignposter(logger: logger)

    /// Runs `body` inside a signpost interval named `name` and logs how long
    /// it took for `rows` rows.
    static func measured<T>(_ name: StaticString, rows: Int, _ body: () -> T) -> T {
        let start = ContinuousClock.now
        let result = signposter.withIntervalSignpost(name, around: body)
        let elapsed = ContinuousClock.now - start
        logger.debug("\(String(describing: name), privacy: .public) \(rows) rows in \(elapsed, privacy: .public)")
        return result
    }
}
