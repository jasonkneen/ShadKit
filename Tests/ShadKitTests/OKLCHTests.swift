import XCTest
@testable import ShadcnUI

/// The shadcn "neutral" base colours are published as OKLCH but every designer
/// checks them as hex. These are the hex values Tailwind/shadcn actually render,
/// so they double as a regression test on the colour-space maths.
final class OKLCHTests: XCTestCase {

    private func assertHex(
        _ oklch: OKLCH,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(oklch.hexString, expected.uppercased(), file: file, line: line)
    }

    func testAchromaticAnchors() {
        assertHex(OKLCH(1, 0, 0), "#FFFFFF")
        assertHex(OKLCH(0, 0, 0), "#000000")
    }

    func testShadcnNeutralRamp() {
        // These map 1:1 onto Tailwind's neutral palette.
        assertHex(OKLCH(0.985, 0, 0), "#FAFAFA")  // neutral-50
        assertHex(OKLCH(0.97, 0, 0), "#F5F5F5")   // neutral-100
        assertHex(OKLCH(0.922, 0, 0), "#E5E5E5")  // neutral-200
        assertHex(OKLCH(0.708, 0, 0), "#A1A1A1")  // neutral-400
        assertHex(OKLCH(0.556, 0, 0), "#737373")  // neutral-500
        assertHex(OKLCH(0.269, 0, 0), "#262626")  // neutral-800
        assertHex(OKLCH(0.205, 0, 0), "#171717")  // neutral-900
        assertHex(OKLCH(0.145, 0, 0), "#0A0A0A")  // neutral-950
    }

    func testChromaticDestructive() {
        // oklch(0.577 0.245 27.325) — shadcn's light-mode destructive.
        assertHex(OKLCH(0.577, 0.245, 27.325), "#E7000B")
        // oklch(0.704 0.191 22.216) — dark-mode destructive.
        assertHex(OKLCH(0.704, 0.191, 22.216), "#FF6467")
    }

    func testOutOfGamutValuesAreClamped() {
        // Wildly out-of-sRGB chroma must still produce a usable colour rather
        // than NaN or a wrapped byte.
        let extreme = OKLCH(0.6, 0.9, 140)
        let rgb = extreme.linearSRGB
        XCTAssertFalse(rgb.r.isNaN || rgb.g.isNaN || rgb.b.isNaN)
        let hex = extreme.hexString
        XCTAssertEqual(hex.count, 7)
        XCTAssertTrue(hex.hasPrefix("#"))
    }

    func testAlphaIsPreserved() {
        let translucent = OKLCH(1, 0, 0, alpha: 0.1)
        XCTAssertEqual(translucent.alpha, 0.1, accuracy: 0.0001)
    }

    // MARK: - CSS parsing

    func testParsesBareOKLCHFunction() throws {
        let parsed = try XCTUnwrap(OKLCH(css: "oklch(0.145 0 0)"))
        assertHex(parsed, "#0A0A0A")
    }

    func testParsesPercentageAlpha() throws {
        let parsed = try XCTUnwrap(OKLCH(css: "oklch(1 0 0 / 10%)"))
        XCTAssertEqual(parsed.alpha, 0.1, accuracy: 0.0001)
        XCTAssertEqual(parsed.l, 1, accuracy: 0.0001)
    }

    func testParsesFractionalAlphaAndPercentLightness() throws {
        let parsed = try XCTUnwrap(OKLCH(css: "oklch(62.8% 0.258 29.234 / 0.5)"))
        XCTAssertEqual(parsed.l, 0.628, accuracy: 0.0001)
        XCTAssertEqual(parsed.c, 0.258, accuracy: 0.0001)
        XCTAssertEqual(parsed.h, 29.234, accuracy: 0.0001)
        XCTAssertEqual(parsed.alpha, 0.5, accuracy: 0.0001)
    }

    func testRejectsGarbage() {
        XCTAssertNil(OKLCH(css: "rgb(1,2,3)"))
        XCTAssertNil(OKLCH(css: "oklch()"))
        XCTAssertNil(OKLCH(css: ""))
    }
}
