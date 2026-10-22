/// Carries AX elements between the main actor and background tasks.
///
/// `AXUIElement` is an immutable reference to another process's element and
/// the AX API may be called from any thread, but the type is not marked
/// `Sendable`. The value is created once and never mutated after it is sent.
///
/// Still needed with Swift 6 and the macOS 27 SDK (checked in #139): a read
/// result leaves its detached task (`AppContentReader`), and a row's element
/// enters one (`OverlayController+Run`). Without the wrapper the compiler
/// rejects both. Remove it once the SDK marks `AXUIElement` `Sendable`.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
