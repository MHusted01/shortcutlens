import AppKit
import SwiftUI

/// A borderless panel that floats above other apps without activating
/// ShortcutLens, so the frontmost app keeps keyboard focus.
///
/// It is shown with `orderFrontRegardless()`, which does not activate the
/// app, and never becomes main. Only as a palette it becomes key, to take
/// typed keys: the frontmost app stays frontmost and keeps its menu bar, and
/// gets keyboard focus back when the panel is ordered out. The surface is an
/// `OverlayBackground`.
///
/// It fades in when it appears and can fade out when it hides; a new
/// `present` during a fade-out cancels it.
@MainActor
final class OverlayPanel: NSPanel {
    private static let showDuration = 0.12
    private static let hideDuration = 0.08
    /// The scale the content grows from while it fades in, without Reduce Motion.
    private static let showScale = 0.98
    private static let contrastBorderWidth: CGFloat = 1

    /// Text editing shortcuts passed on to the search field in palette mode.
    private static let editingActions: [String: Selector] = [
        "a": #selector(NSText.selectAll(_:)),
        "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)),
        "x": #selector(NSText.cut(_:)),
        "z": Selector(("undo:")),
    ]

    private let hostingView = FirstMouseHostingView(rootView: AnyView(EmptyView()))
    /// True while the panel shows as a palette and takes typed keys.
    private var takesKeyboard = false
    /// True while the panel fades out; it is still visible until the fade ends.
    private var isHiding = false
    /// Counts fade-outs, so one that a later show or hide replaced does not
    /// order the panel out when it ends.
    private var hideGeneration = 0

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
        // The fades below replace the system's window animation.
        animationBehavior = .none
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = OverlayBackground.cornerRadius
        contentView = OverlayBackground.make(containing: hostingView)
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
    ///
    /// A panel that was hidden or fading out is ordered front at alpha 0 in
    /// this call and fades in, so the fade never delays the first frame. A
    /// panel already shown only changes its content and frame.
    func present(_ view: some View, frame: CGRect, takesKeyboard: Bool = false) {
        let appears = !isVisible || isHiding
        self.takesKeyboard = takesKeyboard
        hostingView.rootView = AnyView(view)
        setFrame(frame, display: true)
        if appears {
            cancelHide()
            updateContrastBorder()
            alphaValue = 0
        }
        orderFrontRegardless()
        if takesKeyboard {
            makeKey()
        }
        if appears {
            fadeIn()
        }
    }

    /// Orders the panel out, or fades it out first with `animated`. A panel
    /// that is key always hides at once: it keeps keyboard focus until it is
    /// ordered out, so a fade would hold typed keys back from the frontmost
    /// app. Giving up key status here is not reported.
    func dismiss(animated: Bool = false) {
        takesKeyboard = false
        cancelHide()
        guard animated, isVisible, !isKeyWindow else {
            orderOut(nil)
            return
        }
        isHiding = true
        // A row clicked while the panel fades out must not run.
        ignoresMouseEvents = true
        let generation = hideGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                guard let self, generation == hideGeneration else {
                    return
                }
                isHiding = false
                orderOut(nil)
            }
        }
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
    /// swallowed; none reaches the frontmost app. Command with arrows or
    /// Delete is left to the field (line navigation and deletion); no menu
    /// item uses those keys.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard takesKeyboard, event.modifierFlags.contains(.command), event.specialKey == nil else {
            return super.performKeyEquivalent(with: event)
        }
        let isCommandAlone = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        let action = event.charactersIgnoringModifiers.flatMap { Self.editingActions[$0.lowercased()] }
        if isCommandAlone, let action {
            NSApp.sendAction(action, to: nil, from: self)
        }
        return true
    }

    /// Stops a running fade-out, leaving the panel where it is.
    private func cancelHide() {
        hideGeneration += 1
        isHiding = false
        ignoresMouseEvents = false
    }

    private func fadeIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.showDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        // With Reduce Motion the fade alone remains; a fade is not motion.
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let layer = contentView?.layer else {
            return
        }
        let grow = CABasicAnimation(keyPath: "transform")
        let center = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
        grow.fromValue = Self.scaleTransform(Self.showScale, around: center)
        grow.toValue = CATransform3DIdentity
        grow.duration = Self.showDuration
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(grow, forKey: "grow")
    }

    /// Under Increase Contrast, a 1 pt border in the separator colour marks the
    /// panel's edge on macOS 14 and 15. Liquid Glass draws its own border there.
    /// The setting is read on every show, so it needs no observer.
    private func updateContrastBorder() {
        guard let layer = hostingView.layer else {
            return
        }
        let increasesContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        guard increasesContrast, !OverlayBackground.drawsContrastBorder else {
            layer.borderWidth = 0
            return
        }
        layer.borderWidth = Self.contrastBorderWidth
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.borderColor = NSColor.separatorColor.cgColor
        }
    }

    /// Scales by `scale` around `center`; a layer's anchor in AppKit is its corner.
    private static func scaleTransform(_ scale: CGFloat, around center: CGPoint) -> CATransform3D {
        let toCenter = CATransform3DMakeTranslation(center.x, center.y, 0)
        let scaled = CATransform3DScale(toCenter, scale, scale, 1)
        return CATransform3DTranslate(scaled, -center.x, -center.y, 0)
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
