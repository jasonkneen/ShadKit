import XCTest
@testable import ShadcnUI

/// `buttonVariants()` is the most-copied part of shadcn, and its size table was
/// transcribed by hand. These pin the numbers to the Tailwind classes.
final class ButtonMetricsTests: XCTestCase {

    func testHeightsMatchTheTailwindClasses() {
        // h-9 / h-6 / h-8 / h-10, at Tailwind's 4pt spacing unit.
        XCTAssertEqual(ShadcnButtonSize.medium.height, 36)
        XCTAssertEqual(ShadcnButtonSize.xs.height, 24)
        XCTAssertEqual(ShadcnButtonSize.small.height, 32)
        XCTAssertEqual(ShadcnButtonSize.large.height, 40)
    }

    func testIconSizesAreSquareAtTheSameHeights() {
        // size-9 / size-6 / size-8 / size-10.
        XCTAssertEqual(ShadcnButtonSize.icon.height, 36)
        XCTAssertEqual(ShadcnButtonSize.iconXS.height, 24)
        XCTAssertEqual(ShadcnButtonSize.iconSM.height, 32)
        XCTAssertEqual(ShadcnButtonSize.iconLG.height, 40)

        for size in [ShadcnButtonSize.icon, .iconXS, .iconSM, .iconLG] {
            XCTAssertTrue(size.isIconOnly, "\(size) should be square")
            XCTAssertEqual(size.horizontalPadding, 0, "square buttons take no h-padding")
        }
    }

    func testTextSizesAreNotIconOnly() {
        for size in [ShadcnButtonSize.medium, .xs, .small, .large] {
            XCTAssertFalse(size.isIconOnly)
        }
    }

    func testPaddingTightensWhenAnIconIsPresent() {
        // shadcn's `has-[>svg]:px-*` rule: px-4 -> px-3, px-3 -> px-2.5 etc.
        for size in [ShadcnButtonSize.medium, .xs, .small, .large] {
            XCTAssertLessThan(
                size.horizontalPaddingWithIcon, size.horizontalPadding,
                "\(size) must tighten when it leads with an icon")
        }
    }

    func testDefaultPaddingMatchesTheClasses() {
        XCTAssertEqual(ShadcnButtonSize.medium.horizontalPadding, 16)   // px-4
        XCTAssertEqual(ShadcnButtonSize.xs.horizontalPadding, 8)        // px-2
        XCTAssertEqual(ShadcnButtonSize.small.horizontalPadding, 12)    // px-3
        XCTAssertEqual(ShadcnButtonSize.large.horizontalPadding, 24)    // px-6
    }

    func testOnlyTheExtraSmallSizesDropToTextXS() {
        XCTAssertTrue(ShadcnButtonSize.xs.isSmallText)
        XCTAssertTrue(ShadcnButtonSize.iconXS.isSmallText)
        for size in [ShadcnButtonSize.medium, .small, .large, .icon, .iconSM, .iconLG] {
            XCTAssertFalse(size.isSmallText, "\(size) stays at text-sm")
        }
    }

    func testIconGlyphShrinksOnlyForTheXSSizes() {
        // `[&_svg:not([class*='size-'])]:size-3` on xs, size-4 elsewhere.
        XCTAssertEqual(ShadcnButtonSize.xs.iconSize, 12)
        XCTAssertEqual(ShadcnButtonSize.iconXS.iconSize, 12)
        XCTAssertEqual(ShadcnButtonSize.medium.iconSize, 16)
        XCTAssertEqual(ShadcnButtonSize.large.iconSize, 16)
    }

    func testGapsMatchTheClasses() {
        XCTAssertEqual(ShadcnButtonSize.xs.gap, 4)      // gap-1
        XCTAssertEqual(ShadcnButtonSize.small.gap, 6)   // gap-1.5
        XCTAssertEqual(ShadcnButtonSize.medium.gap, 8)  // gap-2
    }

    func testEverySizeAndVariantIsEnumerated() {
        // Guards against a case being added without its metrics.
        XCTAssertEqual(ShadcnButtonSize.allCases.count, 8)
        XCTAssertEqual(ShadcnButtonVariant.allCases.count, 6)
    }
}
