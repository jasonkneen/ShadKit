import XCTest
@testable import ShadcnUI

/// Colour-space edges. Every token in every theme goes through this path, so a
/// silent NaN or a wrapped byte would corrupt a whole palette at once.
final class OKLCHEdgeCaseTests: XCTestCase {

    func testNegativeAndOverbrightLightnessStayInGamut() {
        for lightness in [-1.0, -0.001, 1.5, 99.0] {
            let (r, g, b) = OKLCH(lightness, 0, 0).srgb
            for channel in [r, g, b] {
                XCTAssertFalse(channel.isNaN, "L=\(lightness) produced NaN")
                XCTAssertGreaterThanOrEqual(channel, 0)
                XCTAssertLessThanOrEqual(channel, 1)
            }
        }
    }

    func testHueWrapsRatherThanBreaking() {
        // 0 and 360 are the same hue; -90 and 270 likewise.
        XCTAssertEqual(OKLCH(0.6, 0.1, 0).hexString, OKLCH(0.6, 0.1, 360).hexString)
        XCTAssertEqual(OKLCH(0.6, 0.1, -90).hexString, OKLCH(0.6, 0.1, 270).hexString)
    }

    func testHugeHueValuesAreStillValid() {
        let hex = OKLCH(0.6, 0.1, 100_000).hexString
        XCTAssertEqual(hex.count, 7)
        XCTAssertTrue(hex.hasPrefix("#"))
    }

    func testZeroChromaIsAchromaticAtEveryHue() {
        // The matrix rows sum to 1, so C=0 must be a perfect grey regardless.
        let reference = OKLCH(0.5, 0, 0).hexString
        for hue in stride(from: 0.0, to: 360.0, by: 37) {
            XCTAssertEqual(OKLCH(0.5, 0, hue).hexString, reference, "hue \(hue)")
        }
        let (r, g, b) = OKLCH(0.5, 0, 210).srgb
        XCTAssertEqual(r, g, accuracy: 0.0001)
        XCTAssertEqual(g, b, accuracy: 0.0001)
    }

    func testOpacityHelperCompounds() {
        // `bg-primary/90` then `/50` should land at 45%, not reset.
        let faded = OKLCH(1, 0, 0).opacity(0.9).opacity(0.5)
        XCTAssertEqual(faded.alpha, 0.45, accuracy: 0.0001)
    }

    func testOpacityLeavesTheColourAlone() {
        let base = OKLCH(0.577, 0.245, 27.325)
        XCTAssertEqual(base.opacity(0.3).hexString, base.hexString)
    }

    func testParserRejectsTooFewAndTooManyComponents() {
        XCTAssertNil(OKLCH(css: "oklch(0.5 0.1)"))
        XCTAssertNil(OKLCH(css: "oklch(0.5 0.1 30 40)"))
    }

    func testParserHandlesCommaSeparatedComponents() {
        XCTAssertEqual(OKLCH(css: "oklch(1, 0, 0)")?.hexString, "#FFFFFF")
    }

    func testParserAcceptsAngleUnits() {
        let degrees = OKLCH(css: "oklch(0.6 0.1 180)")
        XCTAssertEqual(OKLCH(css: "oklch(0.6 0.1 180deg)")?.hexString, degrees?.hexString)
        XCTAssertEqual(OKLCH(css: "oklch(0.6 0.1 0.5turn)")?.hexString, degrees?.hexString)
    }

    func testParserTreatsNoneAsZero() {
        // CSS Color 4 allows `none` for a missing component.
        XCTAssertEqual(OKLCH(css: "oklch(1 none none)")?.hexString, "#FFFFFF")
    }

    func testParserIsCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(OKLCH(css: "  OKLCH(1 0 0)  ")?.hexString, "#FFFFFF")
    }

    func testEveryShippedThemeTokenConvertsCleanly() {
        // The real guard: no token in any preset may produce NaN or clip oddly.
        for base in ShadcnBaseColor.all {
            for spec in [base.light, base.dark] {
                for token in [spec.background, spec.foreground, spec.primary,
                              spec.secondary, spec.muted, spec.accent,
                              spec.destructive, spec.border, spec.ring] {
                    let hex = token.hexString
                    XCTAssertEqual(hex.count, 7, "\(base.id) produced \(hex)")
                }
            }
        }
    }
}
