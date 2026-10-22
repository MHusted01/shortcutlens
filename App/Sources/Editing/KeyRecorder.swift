import AppKit
import ShortcutLensCore
import SwiftUI

/// A pressed key as an App Shortcut needs it: the character the key types
/// without modifiers, in the current layout (AppKit's character for named
/// keys such as F1), and the modifiers held. The key code and the shifted
/// character are kept for practice answers.
struct RecordedKeys: Equatable {
    let key: String
    let modifiers: ModifierMask
    let keyCode: Int
    let shiftedKey: String?

    init(_ event: NSEvent) {
        key = ShortcutRecording.key(
            keyCode: Int(event.keyCode),
            layoutCharacter: event.characters(byApplyingModifiers: []) ?? "",
            appKitCharacter: event.charactersIgnoringModifiers ?? ""
        )
        modifiers = ModifierMask(eventFlags: Int(event.modifierFlags.rawValue))
        keyCode = Int(event.keyCode)
        shiftedKey = event.characters(byApplyingModifiers: .shift)
    }
}

/// Takes the keyboard focus and reports every key pressed with it, Command
/// shortcuts included, so they reach neither ShortcutLens's menus nor the
/// window. Draws nothing itself; the view on top shows what was recorded.
struct KeyRecorder: NSViewRepresentable {
    let onKeys: (RecordedKeys) -> Void

    func makeNSView(context _: Context) -> RecorderView {
        let view = RecorderView()
        view.onKeys = onKeys
        return view
    }

    func updateNSView(_ view: RecorderView, context _: Context) {
        view.onKeys = onKeys
    }

    final class RecorderView: NSView {
        var onKeys: (RecordedKeys) -> Void = { _ in }

        override var acceptsFirstResponder: Bool {
            true
        }

        override var focusRingMaskBounds: NSRect {
            bounds
        }

        override func drawFocusRingMask() {
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func mouseDown(with _: NSEvent) {
            window?.makeFirstResponder(self)
        }

        /// Return, keypad Enter and Escape (`kVK_*` codes).
        private static let dialogKeyCodes: Set<UInt16> = [36, 76, 53]

        override func keyDown(with event: NSEvent) {
            guard !Self.isDialogKey(event) else {
                return super.keyDown(with: event)
            }
            onKeys(RecordedKeys(event))
        }

        /// Command shortcuts arrive here before `keyDown` and the menus.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self, event.type == .keyDown, !Self.isDialogKey(event) else {
                return super.performKeyEquivalent(with: event)
            }
            onKeys(RecordedKeys(event))
            return true
        }

        /// Return and Escape without modifiers go to the Save and Cancel
        /// buttons; as App Shortcuts they would need a modifier anyway.
        private static func isDialogKey(_ event: NSEvent) -> Bool {
            let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            return dialogKeyCodes.contains(event.keyCode)
                && event.modifierFlags.isDisjoint(with: modifiers)
        }
    }
}
