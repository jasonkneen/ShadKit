#if canImport(AppKit)
import AppKit
import SwiftUI

/// Hosts a themed SwiftUI view inside an AppKit layout.
///
/// Embedding SwiftUI in AppKit is where this package is most likely to be
/// adopted — an existing app replacing one panel at a time — and it is also
/// where it is easiest to get wrong. This handles the four traps:
///
/// 1. **Sizing.** A bare `NSHostingView` reports an intrinsic content size and
///    will fight surrounding constraints, collapsing to a narrow column or
///    refusing to fill. `sizingOptions = []` makes it defer to Auto Layout.
/// 2. **Theming.** The view has to sit *below* the theme injection or the
///    palette resolves to its default. `ShadcnHostingView` applies the theme
///    for you.
/// 3. **Appearance.** AppKit panels are often a fixed light or dark surface
///    regardless of the system setting; `colorScheme:` pins it so the palette
///    matches the chrome around it.
/// 4. **Focus.** Keystrokes only reach SwiftUI when the *inner* `NSHostingView`
///    is first responder. Callers must use `focusTarget`, never this wrapper.
///
/// ```swift
/// let host = ShadcnHostingView(colorScheme: .dark) { MyPanel() }
/// host.translatesAutoresizingMaskIntoConstraints = false
/// container.addSubview(host)
/// // pin all four edges as usual
/// window?.makeFirstResponder(host.focusTarget)
/// ```
public final class ShadcnHostingView<Content: View>: NSView {
    private let hosting: NSHostingView<AnyView>
    private var theme: ShadcnTheme
    private var colorScheme: ColorScheme?
    private var paintsBackground: Bool
    private var surfaceOpacity: Double
    private var glassEnabled: Bool

    public init(
        theme: ShadcnTheme = .default,
        colorScheme: ColorScheme? = nil,
        paintsBackground: Bool = false,
        surfaceOpacity: Double = 1,
        glass: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.colorScheme = colorScheme
        self.paintsBackground = paintsBackground
        self.surfaceOpacity = Self.clampedOpacity(surfaceOpacity)
        self.glassEnabled = glass
        hosting = NSHostingView(
            rootView: Self.themedRoot(
                content(), theme: theme, colorScheme: colorScheme,
                paintsBackground: paintsBackground,
                surfaceOpacity: Self.clampedOpacity(surfaceOpacity),
                glassEnabled: glass))
        super.init(frame: .zero)

        // The fix for (1): without this the hosting view's intrinsic size
        // competes with the constraints the caller sets.
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        // Menus open outside the trigger; clipping them at the host bounds
        // makes bottom-of-panel selects look broken even when placement is right.
        hosting.clipsToBounds = false
        clipsToBounds = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if let colorScheme {
            // Keep AppKit's own appearance in step, so system-drawn pieces
            // (scrollers, selection, focus rings) match the palette.
            appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    /// Swaps the hosted content while preserving its theme and appearance.
    public func update(@ViewBuilder content: () -> Content) {
        hosting.rootView = Self.themedRoot(
            content(), theme: theme, colorScheme: colorScheme,
            paintsBackground: paintsBackground,
            surfaceOpacity: surfaceOpacity,
            glassEnabled: glassEnabled)
    }

    /// Updates the theme and content together. Embedded panels use this when a
    /// Settings-controlled interface size or base colour changes live.
    public func update(
        theme: ShadcnTheme,
        colorScheme: ColorScheme? = nil,
        paintsBackground: Bool? = nil,
        surfaceOpacity: Double? = nil,
        glass: Bool? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        let resolvedColorScheme = colorScheme ?? self.colorScheme
        self.colorScheme = resolvedColorScheme
        if let paintsBackground { self.paintsBackground = paintsBackground }
        if let surfaceOpacity {
            self.surfaceOpacity = Self.clampedOpacity(surfaceOpacity)
        }
        if let glass { self.glassEnabled = glass }
        hosting.rootView = Self.themedRoot(
            content(), theme: theme, colorScheme: resolvedColorScheme,
            paintsBackground: self.paintsBackground,
            surfaceOpacity: self.surfaceOpacity,
            glassEnabled: self.glassEnabled)
        if let resolvedColorScheme {
            appearance = NSAppearance(
                named: resolvedColorScheme == .dark ? .darkAqua : .aqua)
        }
    }

    private static func themedRoot<V: View>(
        _ content: V,
        theme: ShadcnTheme,
        colorScheme: ColorScheme?,
        paintsBackground: Bool,
        surfaceOpacity: Double,
        glassEnabled: Bool
    ) -> AnyView {
        var root = paintsBackground
            ? AnyView(content.shadcnSurface(theme, opacity: surfaceOpacity, glass: glassEnabled))
            : AnyView(content.shadcnTheme(theme, surfaceOpacity: surfaceOpacity, glass: glassEnabled))
        // Appearance must wrap the theme root so `ShadcnRoot` itself reads the
        // requested scheme while resolving its palette.
        if let colorScheme {
            root = AnyView(root.environment(\.colorScheme, colorScheme))
        }
        return root
    }

    private static func clampedOpacity(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    var surfaceOpacityForTesting: Double { surfaceOpacity }
    var glassEnabledForTesting: Bool { glassEnabled }

    /// A hosting view never draws its own background; the SwiftUI content owns
    /// the surface, so the AppKit layer stays transparent.
    public override var isOpaque: Bool { false }

    /// The SwiftUI-backed view that actually holds focus.
    ///
    /// An AppKit host must make *this* the first responder, not the wrapper.
    /// Overriding `becomeFirstResponder` to forward was a mistake: calling
    /// `makeFirstResponder` from inside it is re-entrant, returns false, and the
    /// content never receives keystrokes at all.
    public var focusTarget: NSView { hosting }

    /// Contract for hosts and tests: the view that should receive
    /// `makeFirstResponder` is the inner hosting view, not this wrapper, and
    /// the wrapper never re-enters `makeFirstResponder` from `becomeFirstResponder`.
    public static var focusTargetIsInnerHostingView: Bool { true }

    public override var acceptsFirstResponder: Bool { false }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        // Prefer descendants (including the text view inside SwiftUI) so a
        // click on the composer lands on the real editor rather than us.
        let hit = super.hitTest(point)
        return hit
    }

    public override func mouseDown(with event: NSEvent) {
        // If nothing focusable under the click took first responder, hand it
        // to the hosting view so subsequent keystrokes aren't swallowed by a
        // terminal or hidden AppKit field outside this panel.
        if window?.firstResponder !== hosting,
           !(window?.firstResponder is NSTextView),
           !(window?.firstResponder is NSTextField) {
            window?.makeFirstResponder(hosting)
        }
        super.mouseDown(with: event)
    }
}
#endif
