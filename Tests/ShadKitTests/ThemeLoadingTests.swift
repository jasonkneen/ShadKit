import XCTest
@testable import ShadcnUI

/// Covers bringing your own theme: the forms shadcn and tweakcn publish, and
/// the round trip back out to hex.
final class ThemeLoadingTests: XCTestCase {

    // MARK: - sRGB -> OKLCH round trip

    func testRoundTripThroughOKLCHPreservesHex() {
        for hex in ["#FFFFFF", "#000000", "#0A0A0A", "#FAFAFA", "#E7000B", "#61AFEF"] {
            let colour = OKLCH(hex: hex)
            XCTAssertEqual(colour?.hexString, hex, "round trip failed for \(hex)")
        }
    }

    func testShorthandHex() {
        XCTAssertEqual(OKLCH(hex: "#fff")?.hexString, "#FFFFFF")
        XCTAssertEqual(OKLCH(hex: "#000")?.hexString, "#000000")
    }

    func testHexAlpha() {
        let half = OKLCH(hex: "#FFFFFF80")
        XCTAssertEqual(half?.alpha ?? 0, 0.502, accuracy: 0.01)
    }

    // MARK: - HSL (shadcn pre-v4)

    func testBareHSLMatchesTheEquivalentHex() {
        // shadcn v3 published `--background: 0 0% 100%`.
        XCTAssertEqual(OKLCH(hsl: "0 0% 100%")?.hexString, "#FFFFFF")
        XCTAssertEqual(OKLCH(hsl: "0 0% 0%")?.hexString, "#000000")
        // Pure red.
        XCTAssertEqual(OKLCH(hsl: "0 100% 50%")?.hexString, "#FF0000")
        XCTAssertEqual(OKLCH(hsl: "120 100% 50%")?.hexString, "#00FF00")
        XCTAssertEqual(OKLCH(hsl: "240 100% 50%")?.hexString, "#0000FF")
    }

    func testWrappedHSLWithAlpha() {
        let parsed = OKLCH(hsl: "hsl(0 0% 100% / 0.5)")
        XCTAssertEqual(parsed?.hexString, "#FFFFFF")
        XCTAssertEqual(parsed?.alpha ?? 0, 0.5, accuracy: 0.001)
    }

    func testThemeValueDispatchesOnForm() {
        XCTAssertEqual(OKLCH(themeValue: "oklch(1 0 0)")?.hexString, "#FFFFFF")
        XCTAssertEqual(OKLCH(themeValue: "#FFFFFF")?.hexString, "#FFFFFF")
        XCTAssertEqual(OKLCH(themeValue: "0 0% 100%")?.hexString, "#FFFFFF")
    }

    // MARK: - Building a spec

    func testPartialThemeFallsBackToNeutral() {
        let spec = ShadcnPaletteSpec(cssVars: ["background": "oklch(0.2 0 0)"])
        XCTAssertEqual(spec.background.hexString, OKLCH(0.2, 0, 0).hexString)
        // Everything unspecified keeps a sensible neutral value.
        XCTAssertEqual(spec.foreground.hexString, "#0A0A0A")
    }

    func testPastedCSSBlockParses() throws {
        let css = """
        :root {
          --background: oklch(1 0 0);
          --foreground: oklch(0.145 0 0);
          --primary: oklch(0.205 0 0);
        }
        """
        let spec = try XCTUnwrap(ShadcnPaletteSpec(css: css))
        XCTAssertEqual(spec.background.hexString, "#FFFFFF")
        XCTAssertEqual(spec.foreground.hexString, "#0A0A0A")
        XCTAssertEqual(spec.primary.hexString, "#171717")
    }

    func testCSSBlockRejectsGarbage() {
        XCTAssertNil(ShadcnPaletteSpec(css: "not a theme"))
        XCTAssertNil(ShadcnPaletteSpec(css: ""))
    }

    // MARK: - Named base colours

    func testEveryBaseColourResolvesBothAppearances() {
        for base in ShadcnBaseColor.all {
            XCTAssertGreaterThan(
                base.dark.foreground.l, base.dark.background.l,
                "\(base.id) dark must be light-on-dark"
            )
            XCTAssertLessThan(
                base.light.foreground.l, base.light.background.l,
                "\(base.id) light must be dark-on-light"
            )
        }
    }

    func testBaseColoursAreActuallyDistinct() {
        // Guards against every preset silently resolving to neutral.
        let backgrounds = Set(ShadcnBaseColor.all.map(\.dark.background.hexString))
        XCTAssertGreaterThan(backgrounds.count, 1)
    }

    func testUnknownNameFallsBackToNeutral() {
        XCTAssertEqual(ShadcnBaseColor.named("nope").id, "neutral")
        XCTAssertEqual(ShadcnBaseColor.named(nil).id, "neutral")
        XCTAssertEqual(ShadcnBaseColor.named("slate").id, "slate")
    }

    func testNeutralStillMatchesTheShippedHexes() {
        // The presets are generated; this pins the one everything else is
        // measured against.
        XCTAssertEqual(ShadcnPaletteSpec.neutralDark.background.hexString, "#0A0A0A")
        XCTAssertEqual(ShadcnPaletteSpec.neutralDark.foreground.hexString, "#FAFAFA")
        XCTAssertEqual(ShadcnPaletteSpec.neutralLight.background.hexString, "#FFFFFF")
    }
}
