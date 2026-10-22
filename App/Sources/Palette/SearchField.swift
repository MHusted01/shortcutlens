import AppKit
import ShortcutLensCore
import SwiftUI

/// The palette's search field. It is an AppKit text field, so arrow keys,
/// Return and Escape arrive as editing commands before the field acts on
/// them, and it takes keyboard focus as soon as it is in a window.
/// `onCommand` returns whether it handled the key; if not, the field does
/// its normal editing (plain Left/Right move the cursor when there is no
/// other column to move to). Option and Command with Left/Right always move
/// the cursor: they arrive as other commands, such as `moveWordLeft:`.
struct SearchField: NSViewRepresentable {
    private static let fontSize: CGFloat = 15

    let text: String
    let onChange: (String) -> Void
    let onCommand: (SearchCommand) -> Bool

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusingTextField()
        let label = String(localized: "Search shortcuts")
        field.placeholderString = label
        // VoiceOver reads the placeholder only while the field is empty.
        field.setAccessibilityLabel(label)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: Self.fontSize)
        field.cell?.usesSingleLineMode = true
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchField

        init(parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else {
                return
            }
            parent.onChange(field.stringValue)
        }

        func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard let command = Self.command(for: selector) else {
                return false
            }
            return parent.onCommand(command)
        }

        private static func command(for selector: Selector) -> SearchCommand? {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                .moveUp
            case #selector(NSResponder.moveDown(_:)):
                .moveDown
            case #selector(NSResponder.moveLeft(_:)):
                .moveLeft
            case #selector(NSResponder.moveRight(_:)):
                .moveRight
            case #selector(NSResponder.insertNewline(_:)):
                .submit
            case #selector(NSResponder.cancelOperation(_:)):
                .cancel
            default:
                nil
            }
        }
    }
}

/// Becomes first responder when added to a window, so typing goes to it as
/// soon as the palette panel is key.
private final class FocusingTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
