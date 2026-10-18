import AppKit
import SwiftUI

/// A borderless panel that floats above other apps without activating
/// ShortcutLens, so the frontmost app keeps keyboard focus.
///
/// It is shown with `orderFrontRegardless()`, which does not activate the
/// app, and never becomes main. Only as a palette it becomes key, to take
/// typed keys: the frontmost app stays frontmost and keeps its menu bar, and
/// gets keyboard focus back when the panel is ordered out. The blurred
/// background is an `NSVisualEffectView` kept `.active`, because ShortcutLens
/// is not the frontmost app while the panel shows.
@MainActor
final class OverlayPanel: NSPanel {
    private static let cornerRadius: CGFloat = 14

    /// Text editing shortcuts passed on to the search field in palette mode.
    private static let editingActions: [String: Selector] = [
        "a": #selector(NSText.selectAll(_:)),
        "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)),
        "x": #selector(NSText.cut(_:)),
    ]

    private let hostingView = FirstMouseHostingView(rootView: AnyView(EmptyView()))
    /// True while the panel shows as a palette and takes typed keys.
    private var takesKeyboard = false

    /// Called when the palette panel stops being key, for example because
    /// Spotlight opened or another window was clicked.
    var onResignKey: () -> Void = {}

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        contentView = makeBackground()
    }

    override var canBecomeKey: Bool {
        takesKeyboard
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Replaces the content, resizes the panel to `frame` and brings it to the
    /// front without activating ShortcutLens. With `takesKeyboard` the panel
    /// also becomes key, so typed keys go to it.
    func present(_ view: some View, frame: CGRect, takesKeyboard: Bool = false) {
        self.takesKeyboard = takesKeyboard
        hostingView.rootView = AnyView(view)
        setFrame(frame, display: true)
        orderFrontRegardless()
        if takesKeyboard {
            makeKey()
        }
    }

    /// Orders the panel out. Giving up key status here is not reported.
    func dismiss() {
        takesKeyboard = false
        orderOut(nil)
    }

    override func resignKey() {
        super.resignKey()
        if takesKeyboard {
            onResignKey()
        }
    }

    /// While the panel is key, ShortcutLens counts as active, so Command
    /// shortcuts would reach its own menu (Cmd+Q would quit it). In palette
    /// mode the editing shortcuts go to the search field and all others are
    /// swallowed; none reaches the frontmost app.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard takesKeyboard, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        let isCommandAlone = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        let action = event.charactersIgnoringModifiers.flatMap { Self.editingActions[$0.lowercased()] }
        if isCommandAlone, let action {
            NSApp.sendAction(action, to: nil, from: self)
        }
        return true
    }

    private func makeBackground() -> NSView {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Self.cornerRadius
        background.layer?.masksToBounds = true

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: background.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        return background
    }
}

/// Outside palette mode the panel is never key and ShortcutLens is not active
/// while it shows, so every click on it is a "first mouse" click. Accepting it lets a row's
/// button fire on that click instead of the click being swallowed.
private final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
