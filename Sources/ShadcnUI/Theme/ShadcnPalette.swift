import SwiftUI

/// The shadcn/ui token set, resolved to concrete colours for one appearance.
///
/// Names mirror the CSS custom properties exactly (`--muted-foreground` →
/// `mutedForeground`) so porting a component is a mechanical translation.
public struct ShadcnPalette: Sendable {
    public var background: Color
    public var foreground: Color
    public var card: Color
    public var cardForeground: Color
    public var popover: Color
    public var popoverForeground: Color
    public var primary: Color
    public var primaryForeground: Color
    public var secondary: Color
    public var secondaryForeground: Color
    public var muted: Color
    public var mutedForeground: Color
    public var accent: Color
    public var accentForeground: Color
    public var destructive: Color
    public var destructiveForeground: Color
    public var border: Color
    public var input: Color
    public var ring: Color
    public var chart1: Color
    public var chart2: Color
    public var chart3: Color
    public var chart4: Color
    public var chart5: Color
    public var sidebar: Color
    public var sidebarForeground: Color
    public var sidebarPrimary: Color
    public var sidebarPrimaryForeground: Color
    public var sidebarAccent: Color
    public var sidebarAccentForeground: Color
    public var sidebarBorder: Color
    public var sidebarRing: Color

    /// True when this palette was built from the dark token set. Components use
    /// it for the handful of `dark:` variants shadcn ships that aren't
    /// expressible as a plain token swap.
    public var isDark: Bool

    public init(
        background: Color,
        foreground: Color,
        card: Color,
        cardForeground: Color,
        popover: Color,
        popoverForeground: Color,
        primary: Color,
        primaryForeground: Color,
        secondary: Color,
        secondaryForeground: Color,
        muted: Color,
        mutedForeground: Color,
        accent: Color,
        accentForeground: Color,
        destructive: Color,
        destructiveForeground: Color,
        border: Color,
        input: Color,
        ring: Color,
        chart1: Color,
        chart2: Color,
        chart3: Color,
        chart4: Color,
        chart5: Color,
        sidebar: Color,
        sidebarForeground: Color,
        sidebarPrimary: Color,
        sidebarPrimaryForeground: Color,
        sidebarAccent: Color,
        sidebarAccentForeground: Color,
        sidebarBorder: Color,
        sidebarRing: Color,
        isDark: Bool
    ) {
        self.background = background
        self.foreground = foreground
        self.card = card
        self.cardForeground = cardForeground
        self.popover = popover
        self.popoverForeground = popoverForeground
        self.primary = primary
        self.primaryForeground = primaryForeground
        self.secondary = secondary
        self.secondaryForeground = secondaryForeground
        self.muted = muted
        self.mutedForeground = mutedForeground
        self.accent = accent
        self.accentForeground = accentForeground
        self.destructive = destructive
        self.destructiveForeground = destructiveForeground
        self.border = border
        self.input = input
        self.ring = ring
        self.chart1 = chart1
        self.chart2 = chart2
        self.chart3 = chart3
        self.chart4 = chart4
        self.chart5 = chart5
        self.sidebar = sidebar
        self.sidebarForeground = sidebarForeground
        self.sidebarPrimary = sidebarPrimary
        self.sidebarPrimaryForeground = sidebarPrimaryForeground
        self.sidebarAccent = sidebarAccent
        self.sidebarAccentForeground = sidebarAccentForeground
        self.sidebarBorder = sidebarBorder
        self.sidebarRing = sidebarRing
        self.isDark = isDark
    }
}

/// The same token set held as OKLCH values, before resolving to `Color`.
///
/// This is the shape you author a custom theme in — every field takes the exact
/// value from a shadcn `:root` / `.dark` block.
public struct ShadcnPaletteSpec: Sendable {
    public var background: OKLCH
    public var foreground: OKLCH
    public var card: OKLCH
    public var cardForeground: OKLCH
    public var popover: OKLCH
    public var popoverForeground: OKLCH
    public var primary: OKLCH
    public var primaryForeground: OKLCH
    public var secondary: OKLCH
    public var secondaryForeground: OKLCH
    public var muted: OKLCH
    public var mutedForeground: OKLCH
    public var accent: OKLCH
    public var accentForeground: OKLCH
    public var destructive: OKLCH
    public var destructiveForeground: OKLCH
    public var border: OKLCH
    public var input: OKLCH
    public var ring: OKLCH
    public var chart1: OKLCH
    public var chart2: OKLCH
    public var chart3: OKLCH
    public var chart4: OKLCH
    public var chart5: OKLCH
    public var sidebar: OKLCH
    public var sidebarForeground: OKLCH
    public var sidebarPrimary: OKLCH
    public var sidebarPrimaryForeground: OKLCH
    public var sidebarAccent: OKLCH
    public var sidebarAccentForeground: OKLCH
    public var sidebarBorder: OKLCH
    public var sidebarRing: OKLCH

    public func resolved(isDark: Bool) -> ShadcnPalette {
        ShadcnPalette(
            background: background.color,
            foreground: foreground.color,
            card: card.color,
            cardForeground: cardForeground.color,
            popover: popover.color,
            popoverForeground: popoverForeground.color,
            primary: primary.color,
            primaryForeground: primaryForeground.color,
            secondary: secondary.color,
            secondaryForeground: secondaryForeground.color,
            muted: muted.color,
            mutedForeground: mutedForeground.color,
            accent: accent.color,
            accentForeground: accentForeground.color,
            destructive: destructive.color,
            destructiveForeground: destructiveForeground.color,
            border: border.color,
            input: input.color,
            ring: ring.color,
            chart1: chart1.color,
            chart2: chart2.color,
            chart3: chart3.color,
            chart4: chart4.color,
            chart5: chart5.color,
            sidebar: sidebar.color,
            sidebarForeground: sidebarForeground.color,
            sidebarPrimary: sidebarPrimary.color,
            sidebarPrimaryForeground: sidebarPrimaryForeground.color,
            sidebarAccent: sidebarAccent.color,
            sidebarAccentForeground: sidebarAccentForeground.color,
            sidebarBorder: sidebarBorder.color,
            sidebarRing: sidebarRing.color,
            isDark: isDark
        )
    }
}
