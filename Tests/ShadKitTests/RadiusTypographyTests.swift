import SwiftUI
import XCTest
@testable import ShadcnUI

/// shadcn derives its whole radius scale from one `--radius`, and Tailwind's
/// type scale from one table. Both were transcribed by hand.
final class RadiusTypographyTests: XCTestCase {

    func testRadiusScaleDerivesFromTheBase() {
        let radius = ShadcnRadius()          // --radius: 0.625rem = 10pt
        XCTAssertEqual(radius.sm, 6)         // calc(var(--radius) - 4px)
        XCTAssertEqual(radius.md, 8)         // calc(var(--radius) - 2px)
        XCTAssertEqual(radius.lg, 10)        // var(--radius)
        XCTAssertEqual(radius.xl, 14)        // calc(var(--radius) + 4px)
    }

    func testRethemingTheBaseMovesTheWholeScale() {
        // The point of one `--radius`: change it and everything follows.
        let sharp = ShadcnRadius(base: 4)
        XCTAssertEqual(sharp.sm, 0)
        XCTAssertEqual(sharp.md, 2)
        XCTAssertEqual(sharp.lg, 4)
        XCTAssertEqual(sharp.xl, 8)
    }

    func testDerivedRadiiNeverGoNegative() {
        // A square theme must clamp, not produce an invalid corner radius.
        let square = ShadcnRadius(base: 0)
        XCTAssertEqual(square.sm, 0)
        XCTAssertEqual(square.md, 0)
    }

    func testTypeScaleMatchesTailwind() {
        let type = ShadcnTypography()
        XCTAssertEqual(type.xs.size, 12)
        XCTAssertEqual(type.sm.size, 14)
        XCTAssertEqual(type.base.size, 16)
        XCTAssertEqual(type.lg.size, 18)
        XCTAssertEqual(type.xl.size, 20)
        XCTAssertEqual(type.xl2.size, 24)
    }

    func testCompactScaleIsSmallerAtEveryStep() {
        let normal = ShadcnTypography()
        let compact = ShadcnTypography.compact()
        XCTAssertLessThan(compact.xs.size, normal.xs.size)
        XCTAssertLessThan(compact.sm.size, normal.sm.size)
        XCTAssertLessThan(compact.base.size, normal.base.size)
        XCTAssertLessThan(compact.xl2.size, normal.xl2.size)
    }

    func testCompactScaleStaysMonotonic() {
        // Shrinking must not reorder the steps.
        let c = ShadcnTypography.compact()
        let sizes = [c.xs.size, c.sm.size, c.base.size, c.lg.size, c.xl.size, c.xl2.size]
        XCTAssertEqual(sizes, sizes.sorted())
    }

    func testLineSpacingIsTheDeltaOverNaturalLeading() {
        // SwiftUI adds leading on top of the font's own line height, so the CSS
        // line-height has to be expressed as a difference, never negative.
        for step in [ShadcnTypography().xs, .init(size: 14, lineHeight: 20)] {
            XCTAssertGreaterThanOrEqual(step.lineSpacing, 0)
        }
        // A line-height below the natural one clamps rather than going negative.
        XCTAssertEqual(ShadcnTypography.Step(size: 40, lineHeight: 10).lineSpacing, 0)
    }

    func testSpacingScaleIsTailwindQuarterRem() {
        XCTAssertEqual(Space.x1, 4)
        XCTAssertEqual(Space.x4, 16)   // p-4
        XCTAssertEqual(Space.x6, 24)
        XCTAssertEqual(Space.step(2.5), 10)
    }

    func testThemeCarriesBothPalettesAndScales() {
        let theme = ShadcnTheme.default
        XCTAssertEqual(theme.radius.lg, 10)
        XCTAssertFalse(theme.palette(for: .light).isDark)
        XCTAssertTrue(theme.palette(for: .dark).isDark)
    }
}
