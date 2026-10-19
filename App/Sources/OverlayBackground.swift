import AppKit

/// The panel's surface: Liquid Glass on macOS 26 and later, a blurred
/// `.popover` material on 14 and 15. Both follow light and dark mode and adapt
/// to Reduce Transparency and Increase Contrast by themselves.
///
/// The surface is the panel's only shape (the panel is borderless and clear),
/// so its corner radius is the panel's.
@MainActor
enum OverlayBackground {
    static var cornerRadius: CGFloat {
        if #available(macOS 26, *) {
            return 18
        }
        return 14
    }

    /// True when the surface outlines itself under Increase Contrast, as
    /// Liquid Glass does (checked on macOS 27).
    static var drawsContrastBorder: Bool {
        if #available(macOS 26, *) {
            return true
        }
        return false
    }

    /// A surface with `content` filling it.
    static func make(containing content: NSView) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            // The glass treats its content view as foreground; a subview would be covered.
            glass.contentView = content
            return glass
        }
        let effect = NSVisualEffectView()
        // Kept active: ShortcutLens is not the frontmost app while the panel shows.
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.masksToBounds = true
        content.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            content.topAnchor.constraint(equalTo: effect.topAnchor),
            content.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        return effect
    }
}
