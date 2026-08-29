import SwiftUI

/// Tailwind's radius scale as shadcn configures it.
///
/// shadcn sets one `--radius` (0.625rem = 10pt) and derives the rest, so
/// re-theming corner rounding is a single number.
public struct ShadcnRadius: Sendable {
    /// `--radius`. Tailwind's `rounded-lg`.
    public var base: CGFloat

    public init(base: CGFloat = 10) {
        self.base = base
    }

    /// `rounded-sm` — `calc(var(--radius) - 4px)`.
    public var sm: CGFloat { max(0, base - 4) }
    /// `rounded-md` — `calc(var(--radius) - 2px)`.
    public var md: CGFloat { max(0, base - 2) }
    /// `rounded-lg` — `var(--radius)`.
    public var lg: CGFloat { base }
    /// `rounded-xl` — `calc(var(--radius) + 4px)`.
    public var xl: CGFloat { base + 4 }
    /// `rounded-full`. Large enough to fully round any realistic control.
    public var full: CGFloat { 9999 }
}

/// Tailwind's type scale. Sizes are points; `lineHeight` is the CSS line-box
/// height, which SwiftUI expresses as extra leading.
public struct ShadcnTypography: Sendable {
    public struct Step: Sendable {
        public var size: CGFloat
        public var lineHeight: CGFloat

        public init(size: CGFloat, lineHeight: CGFloat) {
            self.size = size
            self.lineHeight = lineHeight
        }

        /// SwiftUI applies leading on top of the font's natural line height, so
        /// the CSS line-height has to be expressed as a delta.
        public var lineSpacing: CGFloat { max(0, lineHeight - size * 1.2) }
    }

    public var xs = Step(size: 12, lineHeight: 16)
    public var sm = Step(size: 14, lineHeight: 20)
    public var base = Step(size: 16, lineHeight: 24)
    public var lg = Step(size: 18, lineHeight: 28)
    public var xl = Step(size: 20, lineHeight: 28)
    public var xl2 = Step(size: 24, lineHeight: 32)

    /// Family used for body copy. `nil` means the platform UI font, which is
    /// what shadcn's default stack resolves to on macOS.
    public var sansFamily: String?
    /// Base weight for the sans-serif font. Defaults to `.regular`.
    /// Used by `sans(_:weight:)` to resolve the final weight.
    public var sansWeight: Font.Weight = .regular
    /// Family used for code. `nil` means the platform monospace font.
    public var monoFamily: String?

    public init(
        sansFamily: String? = nil,
        sansWeight: Font.Weight = .regular,
        monoFamily: String? = nil
    ) {
        self.sansFamily = sansFamily
        self.sansWeight = sansWeight
        self.monoFamily = monoFamily
    }

    /// A notch smaller throughout, for dense surfaces like a sidebar panel
    /// where the web scale reads oversized.
    public static func compact(
        sansFamily: String? = nil,
        sansWeight: Font.Weight = .regular,
        monoFamily: String? = nil
    ) -> ShadcnTypography {
        var scale = ShadcnTypography(
            sansFamily: sansFamily,
            sansWeight: sansWeight,
            monoFamily: monoFamily)
        scale.xs = Step(size: 11, lineHeight: 15)
        scale.sm = Step(size: 12.5, lineHeight: 18)
        scale.base = Step(size: 14, lineHeight: 21)
        scale.lg = Step(size: 16, lineHeight: 24)
        scale.xl = Step(size: 18, lineHeight: 26)
        scale.xl2 = Step(size: 21, lineHeight: 28)
        return scale
    }

    /// Scales the complete type ramp, including line boxes, while retaining
    /// the configured font families and weights. Useful for one Settings-controlled
    /// interface size rather than per-component font overrides.
    public func scaled(by factor: CGFloat) -> ShadcnTypography {
        let factor = min(max(factor, 0.7), 1.6)
        func scaled(_ step: Step) -> Step {
            Step(size: step.size * factor, lineHeight: step.lineHeight * factor)
        }
        var result = self
        result.xs = scaled(xs)
        result.sm = scaled(sm)
        result.base = scaled(base)
        result.lg = scaled(lg)
        result.xl = scaled(xl)
        result.xl2 = scaled(xl2)
        result.sansWeight = sansWeight
        return result
    }

    /// Font weight ladder for offset calculation. Ensures component weights
    /// like `.medium` scale relative to the base, not as absolute values.
    /// Base=Regular: .medium stays medium. Base=SemiBold: .medium becomes bold.
    private static let ladder: [Font.Weight] = [
        .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black,
    ]

    /// Resolve a requested weight relative to the configured base weight.
    /// Treats component weights as offsets, not floors — ensures emphasis
    /// scales with the user's chosen font weight.
    static func resolve(_ weight: Font.Weight?, base: Font.Weight) -> Font.Weight {
        guard let weight else { return base }
        guard let requested = ladder.firstIndex(of: weight),
              let baseIndex = ladder.firstIndex(of: base),
              let regular = ladder.firstIndex(of: .regular)
        else { return weight }
        // Offset = (requested - regular); apply that offset to base
        let offset = requested - regular
        let resolved = baseIndex + offset
        return ladder[min(max(resolved, 0), ladder.count - 1)]
    }

    public func sans(_ step: Step, weight: Font.Weight? = nil) -> Font {
        let resolvedWeight = Self.resolve(weight, base: sansWeight)
        if let sansFamily {
            return .custom(sansFamily, size: step.size).weight(resolvedWeight)
        }
        return .system(size: step.size, weight: resolvedWeight)
    }

    public func mono(_ step: Step, weight: Font.Weight = .regular) -> Font {
        if let monoFamily {
            return .custom(monoFamily, size: step.size).weight(weight)
        }
        return .system(size: step.size, weight: weight, design: .monospaced)
    }
}

/// Tailwind's box-shadow scale, translated to SwiftUI's single-shadow model.
///
/// CSS blur radius is roughly twice SwiftUI's, hence the halving. Multi-layer
/// Tailwind shadows collapse to their dominant layer.
public struct ShadcnShadow: Sendable {
    public var color: Color
    public var radius: CGFloat
    public var x: CGFloat
    public var y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }

    /// `shadow-2xs` / `shadow-xs` — `0 1px 2px 0 rgb(0 0 0 / 0.05)`.
    public static let xs = ShadcnShadow(color: .black.opacity(0.05), radius: 1, y: 1)
    /// `shadow-sm` — `0 1px 3px 0 rgb(0 0 0 / 0.1)`.
    public static let sm = ShadcnShadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
    /// `shadow-md` — `0 4px 6px -1px rgb(0 0 0 / 0.1)`.
    public static let md = ShadcnShadow(color: .black.opacity(0.10), radius: 3, y: 2)
    /// `shadow-lg` — `0 10px 15px -3px rgb(0 0 0 / 0.1)`.
    public static let lg = ShadcnShadow(color: .black.opacity(0.10), radius: 7.5, y: 5)
    /// `shadow-xl` — `0 20px 25px -5px rgb(0 0 0 / 0.1)`.
    public static let xl = ShadcnShadow(color: .black.opacity(0.10), radius: 12.5, y: 10)
}

/// Everything a component needs to render: colours for both appearances, plus
/// the radius and type scales.
public struct ShadcnTheme: Sendable {
    public var light: ShadcnPaletteSpec
    public var dark: ShadcnPaletteSpec
    public var radius: ShadcnRadius
    public var typography: ShadcnTypography

    public init(
        light: ShadcnPaletteSpec = .neutralLight,
        dark: ShadcnPaletteSpec = .neutralDark,
        radius: ShadcnRadius = ShadcnRadius(),
        typography: ShadcnTypography = ShadcnTypography()
    ) {
        self.light = light
        self.dark = dark
        self.radius = radius
        self.typography = typography
    }

    /// The stock shadcn look: `new-york` style on the `neutral` base colour.
    public static let `default` = ShadcnTheme()

    public func palette(for scheme: ColorScheme) -> ShadcnPalette {
        scheme == .dark ? dark.resolved(isDark: true) : light.resolved(isDark: false)
    }
}

// MARK: - Spacing

/// Tailwind's spacing unit. `--spacing` is 0.25rem, so `p-4` is `4 * 4 = 16pt`.
///
/// Written as `Space.x4` in ported code to keep the mapping from the original
/// class names obvious.
public enum Space {
    /// Converts a Tailwind spacing step to points.
    @inlinable
    public static func step(_ multiple: CGFloat) -> CGFloat { multiple * 4 }

    public static let px: CGFloat = 1
    public static let x0_5: CGFloat = 2
    public static let x1: CGFloat = 4
    public static let x1_5: CGFloat = 6
    public static let x2: CGFloat = 8
    public static let x2_5: CGFloat = 10
    public static let x3: CGFloat = 12
    public static let x3_5: CGFloat = 14
    public static let x4: CGFloat = 16
    public static let x5: CGFloat = 20
    public static let x6: CGFloat = 24
    public static let x8: CGFloat = 32
    public static let x10: CGFloat = 40
    public static let x12: CGFloat = 48
    public static let x16: CGFloat = 64
    public static let x24: CGFloat = 96
}
