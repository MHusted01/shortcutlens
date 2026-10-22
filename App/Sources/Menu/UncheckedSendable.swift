/// Carries AX elements between the main actor and background tasks.
///
/// `AXUIElement` is an immutable reference to another process's element and
/// the AX API may be called from any thread, but the type is not marked
/// `Sendable`. The value is created once and never mutated after it is sent.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
