import Carbon
import Foundation
import os
import ShortcutLensCore

/// Reads what character keys type on the current keyboard layout, so system
/// shortcuts show the keys the user actually presses.
///
/// Text Input Sources must be used on the main thread, so callers take this
/// snapshot before their background read. An input source without Unicode
/// key data (some input methods) falls back to the ASCII-capable layout; if
/// that fails too, every key falls back to the stored character or the US
/// table in Core.
@MainActor
enum KeyboardLayout {
    private static let log = Logger(subsystem: "dev.shortcutlens", category: "layout")

    /// Every virtual key code; keys that type nothing printable are dropped.
    private static let keyCodes = 0 ..< 128

    static func current() -> KeyLabels {
        guard let data = layoutData() else {
            log.notice("no keyboard layout data, using fallback labels")
            return .none
        }
        let kind = UInt32(LMGetKbdType())
        return data.withUnsafeBytes { bytes in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return .none
            }
            return KeyLabels(keyCodes: keyCodes) { translate(UInt16($0), layout: layout, keyboardType: kind) }
        }
    }

    /// Calls `handler` on the main actor whenever the user selects another
    /// input source. Keep the returned token for as long as it should run.
    static func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated(handler)
        }
    }

    /// The `uchr` data of the current layout, or of the ASCII-capable one.
    private static func layoutData() -> Data? {
        let sources: [() -> Unmanaged<TISInputSource>?] = [
            TISCopyCurrentKeyboardLayoutInputSource, TISCopyCurrentASCIICapableKeyboardLayoutInputSource,
        ]
        for copySource in sources {
            // +1 from `TISCopy*`; released when `source` goes out of scope.
            guard let source = copySource()?.takeRetainedValue(),
                  let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            else {
                continue
            }
            // A Get property is not owned; bridging retains the CFData.
            return Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        }
        return nil
    }

    /// What the key types without modifiers. Dead keys yield their accent
    /// instead of starting a composition.
    private static func translate(
        _ keyCode: UInt16, layout: UnsafePointer<UCKeyboardLayout>, keyboardType: UInt32
    ) -> String? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout, keyCode, UInt16(kUCKeyActionDisplay), 0, keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, characters.count, &length, &characters
        )
        return status == noErr ? String(utf16CodeUnits: characters, count: length) : nil
    }
}
