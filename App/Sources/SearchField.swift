import AppKit
import SwiftUI

/// A key the search field handles itself instead of editing the text.
enum SearchCommand {
    case moveUp
    case moveDown
    case submit
    case cancel
}

/// The palette's search field. It is an AppKit text field, so arrow keys,
/// Return and Escape arrive as editing commands before the field acts on
/// them, and it takes keyboard focus as soon as it is in a window.
struct SearchField: NSViewRepresentable {
    private static let fontSize: CGFloat = 15

    let text: String
    let onChange: (String) -> Void
    let onCommand: (SearchCommand) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusingTextField()
        field.placeholderString = "Search shortcuts"
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
            parent.onCommand(command)
            return true
        }

        private static func command(for selector: Selector) -> SearchCommand? {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                .moveUp
            case #selector(NSResponder.moveDown(_:)):
                .moveDown
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
