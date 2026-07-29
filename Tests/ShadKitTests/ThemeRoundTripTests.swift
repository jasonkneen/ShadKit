import XCTest
@testable import ShadcnUI

/// Bring-your-own-theme is the promise most likely to be exercised by a
/// consumer and least likely to be noticed if it quietly degrades.
final class ThemeRoundTripTests: XCTestCase {

    func testEveryShippedThemeSurvivesACSSRoundTrip() throws {
        // Export a preset to CSS, parse it back, and expect the same colours.
        for base in ShadcnBaseColor.all {
            let spec = base.dark
            let css = """
            :root {
              --background: \(spec.background.hexString);
              --foreground: \(spec.foreground.hexString);
              --primary: \(spec.primary.hexString);
              --muted-foreground: \(spec.mutedForeground.hexString);
            }
            """
            let parsed = try XCTUnwrap(ShadcnPaletteSpec(css: css), base.id)
            XCTAssertEqual(parsed.background.hexString, spec.background.hexString, base.id)
            XCTAssertEqual(parsed.foreground.hexString, spec.foreground.hexString, base.id)
            XCTAssertEqual(parsed.primary.hexString, spec.primary.hexString, base.id)
        }
    }

    func testCSSParsingIgnoresCommentsAndSelectors() throws {
        let css = """
        .dark {
          --background: oklch(0.145 0 0);
          --foreground: oklch(0.985 0 0);
        }
        """
        let spec = try XCTUnwrap(ShadcnPaletteSpec(css: css))
        XCTAssertEqual(spec.background.hexString, "#0A0A0A")
    }

    func testCSSParsingToleratesMissingTrailingSemicolon() throws {
        let spec = try XCTUnwrap(ShadcnPaletteSpec(css: "--background: #FF0000"))
        XCTAssertEqual(spec.background.hexString, "#FF0000")
    }

    func testUnknownVariablesAreIgnoredNotFatal() throws {
        let css = "--background: #FFFFFF; --some-future-token: oklch(0.5 0 0);"
        let spec = try XCTUnwrap(ShadcnPaletteSpec(css: css))
        XCTAssertEqual(spec.background.hexString, "#FFFFFF")
    }

    func testAMixedFormatThemeParses() throws {
        // tweakcn and hand-edited themes routinely mix notations.
        let css = """
        --background: oklch(1 0 0);
        --foreground: 0 0% 0%;
        --primary: #3B82F6;
        """
        let spec = try XCTUnwrap(ShadcnPaletteSpec(css: css))
        XCTAssertEqual(spec.background.hexString, "#FFFFFF")
        XCTAssertEqual(spec.foreground.hexString, "#000000")
        XCTAssertEqual(spec.primary.hexString, "#3B82F6")
    }

    func testFallbackSuppliesUnspecifiedTokens() {
        let spec = ShadcnPaletteSpec(
            cssVars: ["background": "#000000"], fallback: .neutralDark)
        XCTAssertEqual(spec.background.hexString, "#000000")
        // Everything else comes from the fallback, not the built-in default.
        XCTAssertEqual(spec.card.hexString, ShadcnPaletteSpec.neutralDark.card.hexString)
    }

    func testAnInvalidValueFallsBackRatherThanCrashing() {
        let spec = ShadcnPaletteSpec(cssVars: ["background": "not-a-colour"])
        XCTAssertEqual(spec.background.hexString, "#FFFFFF", "bad value takes the default")
    }

    func testResolvedPaletteReportsItsAppearance() {
        XCTAssertTrue(ShadcnPaletteSpec.neutralDark.resolved(isDark: true).isDark)
        XCTAssertFalse(ShadcnPaletteSpec.neutralLight.resolved(isDark: false).isDark)
    }

    func testACustomThemeDrivesTheWholeTheme() {
        let custom = ShadcnBaseColor(
            id: "brand", name: "Brand",
            light: ShadcnPaletteSpec(cssVars: ["primary": "#FF0000"]),
            dark: ShadcnPaletteSpec(cssVars: ["primary": "#00FF00"], fallback: .neutralDark))
        let theme = custom.theme
        XCTAssertEqual(theme.light.primary.hexString, "#FF0000")
        XCTAssertEqual(theme.dark.primary.hexString, "#00FF00")
        XCTAssertEqual(theme.radius.lg, 10, "a colour theme keeps the radius scale")
    }

    func testBaseColourEqualityIsByIdentifier() {
        XCTAssertEqual(ShadcnBaseColor.named("slate"), .slate)
        XCTAssertNotEqual(ShadcnBaseColor.slate, .zinc)
    }
}
