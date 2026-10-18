import AppKit
import SwiftUI

/// A borderless panel that floats above other apps without activating
/// ShortcutLens, so the frontmost app keeps keyboard focus.
///
/// It can never become key or main; it is shown with `orderFrontRegardless()`,
/// which does not activate the app. The blurred background is an
/// `NSVisualEffectView` kept `.active`, because ShortcutLens is never the
/// active app while the panel shows.
@MainActor
final class OverlayPanel: NSPanel {
    private static let cornerRadius: CGFloat = 14

    private let hostingView = FirstMouseHostingView(rootView: AnyView(EmptyView()))

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
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Replaces the content, resizes the panel to `frame` and brings it to the
    /// front without activating ShortcutLens.
    func present(_ view: some View, frame: CGRect) {
        hostingView.rootView = AnyView(view)
        setFrame(frame, display: true)
        orderFrontRegardless()
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

/// The panel is never key and ShortcutLens is never active while it shows, so
/// every click on it is a "first mouse" click. Accepting it lets a row's
/// button fire on that click instead of the click being swallowed.
private final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
