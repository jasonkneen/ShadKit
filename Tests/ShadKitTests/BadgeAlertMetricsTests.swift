import XCTest
@testable import ShadcnUI

/// The remaining variant enums. Each maps to a `cva()` block in the registry
/// JSON and was transcribed by hand.
final class BadgeAlertMetricsTests: XCTestCase {

    func testBadgeVariantsCoverTheRegistrySet() {
        // badgeVariants(): default | secondary | destructive | outline | ghost | link
        XCTAssertEqual(ShadcnBadgeVariant.allCases.count, 6)
    }

    func testAlertVariantsCoverTheRegistrySet() {
        // alertVariants(): default | destructive
        XCTAssertEqual(ShadcnAlertVariant.allCases.count, 2)
    }

    func testAvatarSizesMatchTheClasses() {
        XCTAssertEqual(ShadcnAvatarSize.small.dimension, 24)   // size-6
        XCTAssertEqual(ShadcnAvatarSize.medium.dimension, 32)  // size-8
        XCTAssertEqual(ShadcnAvatarSize.large.dimension, 40)   // size-10
    }

    func testAvatarSizesAreOrdered() {
        let sizes = ShadcnAvatarSize.allCases.map(\.dimension)
        XCTAssertEqual(sizes, sizes.sorted())
    }

    func testSwitchTracksMatchTheClasses() {
        // h-[1.15rem] w-8 and h-3.5 w-6.
        XCTAssertEqual(ShadcnSwitchSize.medium.track.width, 32)
        XCTAssertEqual(ShadcnSwitchSize.small.track.width, 24)
        XCTAssertEqual(ShadcnSwitchSize.small.track.height, 14)
    }

    func testSwitchThumbFitsAndCanTravel() {
        for size in [ShadcnSwitchSize.medium, .small] {
            // Inset by the track's padding, so it never clips vertically.
            XCTAssertLessThanOrEqual(size.thumb, size.track.height)
            // At most half the track, or there'd be no room to slide across.
            XCTAssertLessThanOrEqual(size.thumb, size.track.width / 2)
            XCTAssertGreaterThan(size.thumb, 0)
        }
    }

    func testShadowScaleGrowsMonotonically() {
        // shadow-xs -> shadow-xl must never invert.
        let radii = [
            ShadcnShadow.xs.radius, ShadcnShadow.sm.radius,
            ShadcnShadow.md.radius, ShadcnShadow.lg.radius, ShadcnShadow.xl.radius,
        ]
        XCTAssertEqual(radii, radii.sorted())
    }

    func testShadowOffsetsAreDownward() {
        // CSS drops shadows down the page; a negative y would look inverted.
        for shadow in [ShadcnShadow.xs, .sm, .md, .lg, .xl] {
            XCTAssertGreaterThan(shadow.y, 0)
            XCTAssertEqual(shadow.x, 0)
        }
    }
}
