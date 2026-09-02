#if canImport(AppKit)
import AppKit

/// Makes floating AppKit chrome (NSPopover, Settings, palettes) composite
/// against the desktop instead of a black backing store.
///
/// NSPopover windows default to an opaque interior. SwiftUI materials and
/// `NSVisualEffectView` with `.withinWindow` then sample that interior and
/// render as a black slab even when the host app's window is translucent.
public enum ShadcnWindowTransparency {
    /// Tiny alpha keeps AppKit from swapping in an opaque backing store.
    public static let translucentBacking = NSColor.white.withAlphaComponent(0.001)

    /// Safe to call more than once; intended from `show`, `popoverWillShow`,
    /// and `popoverDidShow` because AppKit resets window opacity after display.
    public static func apply(to window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = translucentBacking

        if let content = window.contentView {
            useBehindWindowEffects(in: content)
            clearOpaqueLayers(in: content)
            if let frame = content.superview {
                useBehindWindowEffects(in: frame)
                clearOpaqueLayers(in: frame)
            }
        }
        window.invalidateShadow()
    }

    public static func apply(to popover: NSPopover?) {
        apply(to: popover?.contentViewController?.view.window)
    }

    /// Frosted content view for a floating panel. Callers add SwiftUI/AppKit
    /// content as a subview; the effect samples whatever is behind the window.
    public static func effectView(
        frame: NSRect,
        material: NSVisualEffectView.Material = .hudWindow,
        cornerRadius: CGFloat = 12
    ) -> NSVisualEffectView {
        let blur = NSVisualEffectView(frame: frame)
        blur.material = material
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerRadius
        blur.layer?.masksToBounds = true
        return blur
    }

    /// Embeds `content` in Liquid Glass on macOS 26+, otherwise a behind-window
    /// visual effect. Prefer this over adding subviews onto `effectView`.
    public static func wrap(
        _ content: NSView,
        frame: NSRect,
        cornerRadius: CGFloat = 12,
        glass: Bool = true
    ) -> NSView {
        content.translatesAutoresizingMaskIntoConstraints = true
        content.autoresizingMask = [.width, .height]
        if glass, #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView(frame: frame)
            glassView.cornerRadius = cornerRadius
            glassView.style = .regular
            glassView.autoresizingMask = [.width, .height]
            content.frame = glassView.bounds
            glassView.contentView = content
            return glassView
        }
        if glass {
            let blur = effectView(
                frame: frame, material: .hudWindow, cornerRadius: cornerRadius)
            content.frame = blur.bounds
            blur.addSubview(content)
            return blur
        }
        content.frame = frame
        return content
    }

    private static func useBehindWindowEffects(in view: NSView) {
        if #available(macOS 26.0, *), view is NSGlassEffectView { return }
        if let effect = view as? NSVisualEffectView {
            effect.blendingMode = .behindWindow
            effect.state = .active
        }
        for subview in view.subviews {
            useBehindWindowEffects(in: subview)
        }
    }

    private static func clearOpaqueLayers(in view: NSView) {
        if #available(macOS 26.0, *), view is NSGlassEffectView { return }
        let skip = view is NSVisualEffectView
            || view is NSControl
            || view is NSScrollView
            || view is NSTableView
        if !skip {
            view.wantsLayer = true
            view.layer?.isOpaque = false
            view.layer?.backgroundColor = NSColor.clear.cgColor
        }
        for subview in view.subviews {
            clearOpaqueLayers(in: subview)
        }
    }
}
#endif
