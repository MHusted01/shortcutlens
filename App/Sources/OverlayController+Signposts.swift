import os

/// Signpost intervals for the steps between holding Command and seeing the
/// overlay, shown in Instruments under the "overlay" category.
extension OverlayController {
    nonisolated static let signposter = OSSignposter(logger: log)

    /// Runs `body` inside a signpost interval named `name` and logs how long
    /// it took for `rows` rows. Counts and timing only, never app names or titles.
    nonisolated static func measured<T>(_ name: StaticString, rows: Int, _ body: () -> T) -> T {
        let start = ContinuousClock.now
        let result = signposter.withIntervalSignpost(name, around: body)
        let elapsed = ContinuousClock.now - start
        log.notice("\(String(describing: name), privacy: .public) \(rows) rows in \(elapsed, privacy: .public)")
        return result
    }
}
