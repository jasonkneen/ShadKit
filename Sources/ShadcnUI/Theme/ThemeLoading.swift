import Foundation

// MARK: - sRGB -> OKLCH

extension OKLCH {
    /// Builds an OKLCH colour from gamma-encoded sRGB components (0...1).
    ///
    /// The inverse of `srgb`, so themes authored in HSL or hex can be stored in
    /// the same representation as the OKLCH ones.
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        func linearise(_ channel: Double) -> Double {
            channel <= 0.040_45
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }

        let r = linearise(min(max(red, 0), 1))
        let g = linearise(min(max(green, 0), 1))
        let b = linearise(min(max(blue, 0), 1))

        // Linear sRGB -> LMS.
        let long = 0.412_221_470_8 * r + 0.536_332_536_3 * g + 0.051_445_992_9 * b
        let medium = 0.211_903_498_2 * r + 0.680_699_545_1 * g + 0.107_396_956_6 * b
        let short = 0.088_302_461_9 * r + 0.281_718_837_6 * g + 0.629_978_700_5 * b

        let lRoot = Foundation.cbrt(long)
        let mRoot = Foundation.cbrt(medium)
        let sRoot = Foundation.cbrt(short)

        // LMS' -> OKLab.
        let labL = 0.210_454_255_3 * lRoot + 0.793_617_785_0 * mRoot - 0.004_072_046_8 * sRoot
        let labA = 1.977_998_495_1 * lRoot - 2.428_592_205_0 * mRoot + 0.450_593_709_9 * sRoot
        let labB = 0.025_904_037_1 * lRoot + 0.782_771_766_2 * mRoot - 0.808_675_766_0 * sRoot

        let chroma = (labA * labA + labB * labB).squareRoot()
        var hue = atan2(labB, labA) * 180 / .pi
        if hue < 0 { hue += 360 }

        self.init(l: labL, c: chroma, h: hue, alpha: alpha)
    }

    /// Parses `#RGB`, `#RRGGBB` or `#RRGGBBAA`.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        guard text.hasPrefix("#") else { return nil }
        text.removeFirst()

        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6 || text.count == 8,
              let value = UInt32(text, radix: 16)
        else { return nil }

        let hasAlpha = text.count == 8
        let shift = hasAlpha ? 8 : 0
        let r = Double((value >> (16 + shift)) & 0xFF) / 255
        let g = Double((value >> (8 + shift)) & 0xFF) / 255
        let b = Double((value >> shift) & 0xFF) / 255
        let a = hasAlpha ? Double(value & 0xFF) / 255 : 1

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    /// Parses shadcn's pre-v4 HSL form — bare `H S% L%`, optionally
    /// `hsl(H S% L% / A)`.
    public init?(hsl: String) {
        var text = hsl.trimmingCharacters(in: .whitespaces).lowercased()
        if text.hasPrefix("hsl(") , text.hasSuffix(")") {
            text = String(text.dropFirst(4).dropLast())
        }

        let sides = text.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let parts = sides[0]
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .map { $0.replacingOccurrences(of: "%", with: "") }
        guard parts.count == 3,
              let h = Double(parts[0]),
              let s = Double(parts[1]),
              let l = Double(parts[2])
        else { return nil }

        var alpha = 1.0
        if sides.count == 2 {
            let raw = sides[1].trimmingCharacters(in: .whitespaces)
            if raw.hasSuffix("%") {
                guard let value = Double(raw.dropLast()) else { return nil }
                alpha = value / 100
            } else if let value = Double(raw) {
                alpha = value
            } else {
                return nil
            }
        }

        let (r, g, b) = Self.hslToRGB(h: h, s: s / 100, l: l / 100)
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    private static func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
        let chroma = (1 - abs(2 * l - 1)) * s
        let sector = (h.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) / 60
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let match = l - chroma / 2

        let rgb: (Double, Double, Double)
        switch sector {
        case ..<1: rgb = (chroma, x, 0)
        case ..<2: rgb = (x, chroma, 0)
        case ..<3: rgb = (0, chroma, x)
        case ..<4: rgb = (0, x, chroma)
        case ..<5: rgb = (x, 0, chroma)
        default: rgb = (chroma, 0, x)
        }
        return (rgb.0 + match, rgb.1 + match, rgb.2 + match)
    }

    /// Parses any colour form a shadcn theme is published in.
    public init?(themeValue: String) {
        let text = themeValue.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("oklch") {
            self.init(css: text)
        } else if text.hasPrefix("#") {
            self.init(hex: text)
        } else {
            self.init(hsl: text)
        }
    }
}

// MARK: - Building a spec from theme variables

extension ShadcnPaletteSpec {
    /// Builds a palette from a shadcn theme's CSS custom properties.
    ///
    /// Keys are the bare variable names (`background`, `muted-foreground`, …)
    /// in any published form — v4 OKLCH, pre-v4 HSL, or hex. This is what makes
    /// a theme copied out of shadcn or tweakcn usable as-is:
    ///
    /// ```swift
    /// ShadcnPaletteSpec(cssVars: [
    ///     "background": "oklch(1 0 0)",
    ///     "foreground": "oklch(0.145 0 0)",
    /// ])
    /// ```
    ///
    /// Anything omitted falls back to the neutral value for that slot, so a
    /// partial theme still produces a complete palette.
    public init(cssVars: [String: String], fallback: ShadcnPaletteSpec? = nil) {
        // `fallback` is optional to break the cycle when neutral itself is
        // being constructed.
        func value(_ key: String, _ base: OKLCH) -> OKLCH {
            guard let raw = cssVars[key], let parsed = OKLCH(themeValue: raw) else { return base }
            return parsed
        }

        let base = fallback
        self.init(
            background: value("background", base?.background ?? OKLCH(1, 0, 0)),
            foreground: value("foreground", base?.foreground ?? OKLCH(0.145, 0, 0)),
            card: value("card", base?.card ?? OKLCH(1, 0, 0)),
            cardForeground: value("card-foreground", base?.cardForeground ?? OKLCH(0.145, 0, 0)),
            popover: value("popover", base?.popover ?? OKLCH(1, 0, 0)),
            popoverForeground: value("popover-foreground", base?.popoverForeground ?? OKLCH(0.145, 0, 0)),
            primary: value("primary", base?.primary ?? OKLCH(0.205, 0, 0)),
            primaryForeground: value("primary-foreground", base?.primaryForeground ?? OKLCH(0.985, 0, 0)),
            secondary: value("secondary", base?.secondary ?? OKLCH(0.97, 0, 0)),
            secondaryForeground: value("secondary-foreground", base?.secondaryForeground ?? OKLCH(0.205, 0, 0)),
            muted: value("muted", base?.muted ?? OKLCH(0.97, 0, 0)),
            mutedForeground: value("muted-foreground", base?.mutedForeground ?? OKLCH(0.556, 0, 0)),
            accent: value("accent", base?.accent ?? OKLCH(0.97, 0, 0)),
            accentForeground: value("accent-foreground", base?.accentForeground ?? OKLCH(0.205, 0, 0)),
            destructive: value("destructive", base?.destructive ?? OKLCH(0.577, 0.245, 27.325)),
            destructiveForeground: value("destructive-foreground", base?.destructiveForeground ?? OKLCH(1, 0, 0)),
            border: value("border", base?.border ?? OKLCH(0.922, 0, 0)),
            input: value("input", base?.input ?? OKLCH(0.922, 0, 0)),
            ring: value("ring", base?.ring ?? OKLCH(0.708, 0, 0)),
            chart1: value("chart-1", base?.chart1 ?? OKLCH(0.87, 0, 0)),
            chart2: value("chart-2", base?.chart2 ?? OKLCH(0.556, 0, 0)),
            chart3: value("chart-3", base?.chart3 ?? OKLCH(0.439, 0, 0)),
            chart4: value("chart-4", base?.chart4 ?? OKLCH(0.371, 0, 0)),
            chart5: value("chart-5", base?.chart5 ?? OKLCH(0.269, 0, 0)),
            sidebar: value("sidebar", base?.sidebar ?? OKLCH(0.985, 0, 0)),
            sidebarForeground: value("sidebar-foreground", base?.sidebarForeground ?? OKLCH(0.145, 0, 0)),
            sidebarPrimary: value("sidebar-primary", base?.sidebarPrimary ?? OKLCH(0.205, 0, 0)),
            sidebarPrimaryForeground: value("sidebar-primary-foreground", base?.sidebarPrimaryForeground ?? OKLCH(0.985, 0, 0)),
            sidebarAccent: value("sidebar-accent", base?.sidebarAccent ?? OKLCH(0.97, 0, 0)),
            sidebarAccentForeground: value("sidebar-accent-foreground", base?.sidebarAccentForeground ?? OKLCH(0.205, 0, 0)),
            sidebarBorder: value("sidebar-border", base?.sidebarBorder ?? OKLCH(0.922, 0, 0)),
            sidebarRing: value("sidebar-ring", base?.sidebarRing ?? OKLCH(0.708, 0, 0))
        )
    }

    /// Parses a `:root { --background: …; }` style CSS block.
    ///
    /// Lets a theme be pasted verbatim out of shadcn's theme editor or tweakcn
    /// without hand-transcribing it into a dictionary.
    public init?(css: String, fallback: ShadcnPaletteSpec? = nil) {
        var vars: [String: String] = [:]
        for line in css.split(whereSeparator: { $0 == ";" || $0 == "\n" }) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("--"),
                  let colon = trimmed.firstIndex(of: ":")
            else { continue }
            let name = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<colon])
                .trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !value.isEmpty else { continue }
            vars[name] = value
        }
        guard !vars.isEmpty else { return nil }
        self.init(cssVars: vars, fallback: fallback)
    }
}
