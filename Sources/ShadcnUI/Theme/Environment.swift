import SwiftUI

private struct ShadcnThemeKey: EnvironmentKey {
    static let defaultValue = ShadcnTheme.default
}

private struct ShadcnPaletteKey: EnvironmentKey {
    // Resolving against .light here is only a placeholder — `ShadcnRoot`
    // (installed by `.shadcnTheme(_:)`) always overwrites it with the palette
    // for the live colour scheme.
    static let defaultValue = ShadcnTheme.default.palette(for: .light)
}

private struct ShadcnSurfaceOpacityKey: EnvironmentKey {
    static let defaultValue = 1.0
}

private struct ShadcnHostProvidesGlassKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ShadcnGlassEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct ShadcnFloatingPanelHostedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The active theme. Read this when you need the radius or type scale.
    public var shadcnTheme: ShadcnTheme {
        get { self[ShadcnThemeKey.self] }
        set { self[ShadcnThemeKey.self] = newValue }
    }

    /// The active theme's colours, already resolved for the current appearance.
    ///
    /// This is what components read; it saves every view from having to observe
    /// `colorScheme` itself.
    public var shadcnPalette: ShadcnPalette {
        get { self[ShadcnPaletteKey.self] }
        set { self[ShadcnPaletteKey.self] = newValue }
    }

    /// Opacity applied to full-panel background tokens. Components use this
    /// for their outer surface only, keeping text and controls fully legible.
    public var shadcnSurfaceOpacity: Double {
        get { self[ShadcnSurfaceOpacityKey.self] }
        set { self[ShadcnSurfaceOpacityKey.self] = min(max(newValue, 0), 1) }
    }

    /// True when an AppKit visual-effect view already frosts this surface.
    /// Overlay fills then apply only a light tint, not a second material.
    public var shadcnHostProvidesGlass: Bool {
        get { self[ShadcnHostProvidesGlassKey.self] }
        set { self[ShadcnHostProvidesGlassKey.self] = newValue }
    }

    /// Frosted materials on panels and overlays. Independent of surface
    /// opacity: native menus stay glass over an opaque pane.
    public var shadcnGlassEnabled: Bool {
        get { self[ShadcnGlassEnabledKey.self] }
        set { self[ShadcnGlassEnabledKey.self] = newValue }
    }

    /// True inside content hosted by `ShadcnFloatingPanelController`. Such a
    /// panel sits over the window's own content, so a glass or translucent
    /// surface blurs the transcript behind it into smears; fills paint solid.
    public var shadcnFloatingPanelHosted: Bool {
        get { self[ShadcnFloatingPanelHostedKey.self] }
        set { self[ShadcnFloatingPanelHostedKey.self] = newValue }
    }
}

/// How overlay/panel fills behave when glass is on or the host is translucent.
public enum ShadcnSurfaceFill {
    /// Cap on the colour wash over material. A higher floor of the popover
    /// token (near-black in dark themes) is what made menus look like slabs.
    public static let maximumTranslucentTint = 0.18

    public static func usesMaterial(glass: Bool) -> Bool { glass }

    public static func tintOpacity(_ surfaceOpacity: Double, glass: Bool) -> Double {
        let opacity = min(max(surfaceOpacity, 0), 1)
        guard glass else { return opacity }
        return min(opacity * 0.4, maximumTranslucentTint)
    }
}

/// Rounded fill: Liquid Glass when glass is on (macOS 26+ / iOS 26+), a
/// material fallback on older systems, otherwise a flat colour.
public struct ShadcnTranslucentFill: View {
    var color: Color
    var cornerRadius: CGFloat
    var material: Material

    @Environment(\.shadcnSurfaceOpacity) private var surfaceOpacity
    @Environment(\.shadcnHostProvidesGlass) private var hostProvidesGlass
    @Environment(\.shadcnGlassEnabled) private var glassEnabled
    @Environment(\.shadcnFloatingPanelHosted) private var floatingPanelHosted

    public init(
        color: Color,
        cornerRadius: CGFloat,
        material: Material = .regularMaterial
    ) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.material = material
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if floatingPanelHosted {
            // Solid: glass would blur the window content behind the panel.
            shape.fill(color)
        } else if glassEnabled {
            if hostProvidesGlass {
                Color.clear
            } else {
                liquidGlass(in: shape)
            }
        } else {
            shape.fill(color.opacity(min(max(surfaceOpacity, 0), 1)))
        }
    }

    @ViewBuilder
    private func liquidGlass(in shape: RoundedRectangle) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            // Native Liquid Glass — the same material system menus use.
            // Do not paint a dark colour wash on top; that is what made
            // ShadKit panels look like black slabs instead of glass.
            Color.clear
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            materialFallback(in: shape)
        }
        #else
        materialFallback(in: shape)
        #endif
    }

    private func materialFallback(in shape: RoundedRectangle) -> some View {
        ZStack {
            shape.fill(material)
            shape.fill(
                color.opacity(
                    ShadcnSurfaceFill.tintOpacity(surfaceOpacity, glass: true)))
        }
    }
}

/// Injects a theme and keeps its resolved palette in sync with the appearance.
private struct ShadcnRoot: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let theme: ShadcnTheme
    /// Paints the `background` token behind the content.
    let paintsBackground: Bool
    let surfaceOpacity: Double
    let glassEnabled: Bool

    func body(content: Content) -> some View {
        let palette = theme.palette(for: colorScheme)

        // The backdrop is resolved here rather than by a nested view reading
        // `\.shadcnPalette`: a `.background(…)` attached outside this modifier
        // would read the palette from *above* the injection — i.e. the default
        // light one — and paint a white surface under a dark UI.
        content
            .environment(\.shadcnTheme, theme)
            .environment(\.shadcnPalette, palette)
            .environment(\.shadcnSurfaceOpacity, surfaceOpacity)
            .environment(\.shadcnGlassEnabled, glassEnabled)
            .background(
                paintsBackground
                    ? palette.background.opacity(surfaceOpacity)
                    : .clear
            )
            // Popovers, dropdowns and selects draw here rather than inline, so
            // no ancestor's stacking order can paint over an open panel.
            .modifier(
                ShadcnOverlayHost(
                    theme: theme, palette: palette, colorScheme: colorScheme,
                    surfaceOpacity: surfaceOpacity,
                    glassEnabled: glassEnabled)
            )
    }
}

extension View {
    /// Applies a shadcn theme to this subtree.
    ///
    /// Apply once near the root. Components below pick up both the tokens and
    /// the correct light/dark palette automatically.
    public func shadcnTheme(
        _ theme: ShadcnTheme = .default,
        surfaceOpacity: Double = 1,
        glass: Bool = true
    ) -> some View {
        modifier(ShadcnRoot(
            theme: theme,
            paintsBackground: false,
            surfaceOpacity: min(max(surfaceOpacity, 0), 1),
            glassEnabled: glass))
    }

    /// Applies the theme *and* paints the `background` token behind the
    /// content, matching what a shadcn page body does.
    public func shadcnSurface(
        _ theme: ShadcnTheme = .default,
        opacity: Double = 1,
        glass: Bool = true
    ) -> some View {
        modifier(ShadcnRoot(
            theme: theme,
            paintsBackground: true,
            surfaceOpacity: min(max(opacity, 0), 1),
            glassEnabled: glass))
    }
}

// MARK: - Shared view helpers

extension View {
    /// Applies a `ShadcnShadow`.
    public func shadcnShadow(_ shadow: ShadcnShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Rounded-rect border drawn inside the bounds, the way CSS `border` sits.
    ///
    /// SwiftUI strokes centred on the path, so the shape is inset by half the
    /// line width to keep the outer edge where CSS would put it.
    public func shadcnBorder(
        _ color: Color,
        width: CGFloat = 1,
        cornerRadius: CGFloat
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: width / 2)
                .stroke(color, lineWidth: width)
        )
    }

    /// shadcn's focus treatment: a 1pt ring in `ring`, plus a 3pt halo at 50%.
    @ViewBuilder
    public func shadcnFocusRing(
        _ isFocused: Bool,
        palette: ShadcnPalette,
        cornerRadius: CGFloat
    ) -> some View {
        if isFocused {
            overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: -0.5)
                    .stroke(palette.ring, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: -2)
                    .stroke(palette.ring.opacity(0.5), lineWidth: 3)
            )
        } else {
            self
        }
    }

    /// Applies a modifier only when a condition holds. Keeps ported components
    /// readable where the original used a conditional class.
    @ViewBuilder
    public func applyIf(
        _ condition: Bool,
        @ViewBuilder transform: (Self) -> some View
    ) -> some View {
        if condition { transform(self) } else { self }
    }
}
