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
}

/// Injects a theme and keeps its resolved palette in sync with the appearance.
private struct ShadcnRoot: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let theme: ShadcnTheme
    /// Paints the `background` token behind the content.
    let paintsBackground: Bool

    func body(content: Content) -> some View {
        let palette = theme.palette(for: colorScheme)

        // The backdrop is resolved here rather than by a nested view reading
        // `\.shadcnPalette`: a `.background(…)` attached outside this modifier
        // would read the palette from *above* the injection — i.e. the default
        // light one — and paint a white surface under a dark UI.
        content
            .environment(\.shadcnTheme, theme)
            .environment(\.shadcnPalette, palette)
            .background(paintsBackground ? palette.background : .clear)
            // Popovers, dropdowns and selects draw here rather than inline, so
            // no ancestor's stacking order can paint over an open panel.
            .modifier(
                ShadcnOverlayHost(
                    theme: theme, palette: palette, colorScheme: colorScheme)
            )
    }
}

extension View {
    /// Applies a shadcn theme to this subtree.
    ///
    /// Apply once near the root. Components below pick up both the tokens and
    /// the correct light/dark palette automatically.
    public func shadcnTheme(_ theme: ShadcnTheme = .default) -> some View {
        modifier(ShadcnRoot(theme: theme, paintsBackground: false))
    }

    /// Applies the theme *and* paints the `background` token behind the
    /// content, matching what a shadcn page body does.
    public func shadcnSurface(_ theme: ShadcnTheme = .default) -> some View {
        modifier(ShadcnRoot(theme: theme, paintsBackground: true))
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
