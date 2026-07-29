import CoreGraphics
import Foundation
import SwiftUI

/// A colour in the OKLCH space — the space shadcn/ui publishes all of its
/// design tokens in.
///
/// Ports of shadcn themes paste in as-is:
/// ```swift
/// OKLCH(css: "oklch(0.145 0 0)")
/// OKLCH(css: "oklch(1 0 0 / 10%)")
/// ```
public struct OKLCH: Hashable, Sendable {
    /// Perceptual lightness, 0...1.
    public var l: Double
    /// Chroma. 0 is achromatic; sRGB tops out around 0.37.
    public var c: Double
    /// Hue angle in degrees.
    public var h: Double
    /// Opacity, 0...1.
    public var alpha: Double

    public init(l: Double, c: Double, h: Double, alpha: Double = 1) {
        self.l = l
        self.c = c
        self.h = h
        self.alpha = alpha
    }

    /// Positional shorthand matching CSS argument order.
    public init(_ l: Double, _ c: Double, _ h: Double, alpha: Double = 1) {
        self.init(l: l, c: c, h: h, alpha: alpha)
    }

    /// Returns a copy with a different opacity — the Swift equivalent of
    /// Tailwind's `bg-primary/90` slash syntax.
    public func opacity(_ value: Double) -> OKLCH {
        OKLCH(l: l, c: c, h: h, alpha: alpha * value)
    }
}

// MARK: - Conversion

extension OKLCH {
    /// OKLab coordinates (L, a, b).
    public var oklab: (l: Double, a: Double, b: Double) {
        let radians = h * .pi / 180
        return (l, c * cos(radians), c * sin(radians))
    }

    /// Linear-light sRGB. Components may fall outside 0...1 when the colour is
    /// outside the sRGB gamut; `srgb` clamps them.
    public var linearSRGB: (r: Double, g: Double, b: Double) {
        let (labL, labA, labB) = oklab

        // OKLab -> approximate cone response (Björn Ottosson's LMS').
        let lPrime = labL + 0.396_337_777_4 * labA + 0.215_803_757_3 * labB
        let mPrime = labL - 0.105_561_345_8 * labA - 0.063_854_172_8 * labB
        let sPrime = labL - 0.089_484_177_5 * labA - 1.291_485_548_0 * labB

        let long = lPrime * lPrime * lPrime
        let medium = mPrime * mPrime * mPrime
        let short = sPrime * sPrime * sPrime

        // LMS -> linear sRGB.
        return (
            r: 4.076_741_662_1 * long - 3.307_711_591_3 * medium + 0.230_969_929_2 * short,
            g: -1.268_438_004_6 * long + 2.609_757_401_1 * medium - 0.341_319_396_5 * short,
            b: -0.004_196_086_3 * long - 0.703_418_614_7 * medium + 1.707_614_701_0 * short
        )
    }

    /// Gamma-encoded sRGB, clamped into gamut.
    public var srgb: (r: Double, g: Double, b: Double) {
        let linear = linearSRGB
        return (
            Self.gammaEncode(linear.r),
            Self.gammaEncode(linear.g),
            Self.gammaEncode(linear.b)
        )
    }

    private static func gammaEncode(_ channel: Double) -> Double {
        guard channel.isFinite else { return 0 }
        let encoded: Double
        if channel <= 0.003_130_8 {
            encoded = channel * 12.92
        } else {
            encoded = 1.055 * pow(channel, 1.0 / 2.4) - 0.055
        }
        return min(max(encoded, 0), 1)
    }

    /// Uppercase `#RRGGBB`. Alpha is not encoded — it lives on the `Color`.
    public var hexString: String {
        let (r, g, b) = srgb
        let ri = Int((r * 255).rounded())
        let gi = Int((g * 255).rounded())
        let bi = Int((b * 255).rounded())
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    /// A SwiftUI colour in the sRGB space.
    public var color: Color {
        let (r, g, b) = srgb
        return Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - CSS parsing

extension OKLCH {
    /// Parses the CSS `oklch()` function so shadcn themes can be pasted in
    /// verbatim. Accepts `oklch(L C H)` and `oklch(L C H / A)`, where `L` and
    /// `A` may be percentages.
    ///
    /// Returns `nil` for anything that isn't a well-formed `oklch()` call.
    public init?(css: String) {
        let trimmed = css.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.hasPrefix("oklch("), trimmed.hasSuffix(")") else { return nil }

        let inner = String(trimmed.dropFirst("oklch(".count).dropLast())
        let sides = inner.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)

        let components = sides[0]
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .map(String.init)
        guard components.count == 3 else { return nil }

        guard let lightness = Self.parseComponent(components[0], percentScale: 1),
              let chroma = Self.parseComponent(components[1], percentScale: 0.4),
              let hue = Self.parseAngle(components[2])
        else { return nil }

        var opacity = 1.0
        if sides.count == 2 {
            let raw = sides[1].trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty, let parsed = Self.parseComponent(raw, percentScale: 1) else {
                return nil
            }
            opacity = parsed
        }

        self.init(l: lightness, c: chroma, h: hue, alpha: opacity)
    }

    /// `50%` becomes `0.5 * percentScale`; a bare number passes through.
    /// `percentScale` exists because CSS defines 100% chroma as 0.4.
    private static func parseComponent(_ raw: String, percentScale: Double) -> Double? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if text.hasSuffix("%") {
            guard let value = Double(text.dropLast()) else { return nil }
            return value / 100 * percentScale
        }
        if text == "none" { return 0 }
        return Double(text)
    }

    private static func parseAngle(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if text == "none" { return 0 }
        for unit in ["deg", "grad", "rad", "turn"] where text.hasSuffix(unit) {
            let magnitude = Double(text.dropLast(unit.count))
            guard let magnitude else { return nil }
            switch unit {
            case "deg": return magnitude
            case "grad": return magnitude * 0.9
            case "rad": return magnitude * 180 / .pi
            default: return magnitude * 360
            }
        }
        if text.hasSuffix("%") { text = String(text.dropLast()) }
        return Double(text)
    }
}

// MARK: - Convenience

extension Color {
    /// Builds a colour from OKLCH values, matching CSS argument order.
    public static func oklch(_ l: Double, _ c: Double, _ h: Double, alpha: Double = 1) -> Color {
        OKLCH(l, c, h, alpha: alpha).color
    }
}
