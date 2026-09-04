import XCTest
@testable import ShadcnUI

/// Pins `ShadcnTabs`' U20 `height:`/`labelSize:` additions: the default must
/// stay exactly what every pre-U20 caller already gets.
final class TabsSizingTests: XCTestCase {

    func testNilHeightKeepsThePreU20DefaultOf36() {
        XCTAssertEqual(shadcnTabsResolvedHeight(nil), 36)
    }

    func testExplicitHeightIsHonoured() {
        XCTAssertEqual(shadcnTabsResolvedHeight(44), 44)
    }

    func testSmallLabelSizeKeepsTheOriginal14ptIcon() {
        XCTAssertEqual(ShadcnTabsLabelSize.small.iconSize, 14)
    }

    func testRegularLabelSizeUsesA16ptIcon() {
        XCTAssertEqual(ShadcnTabsLabelSize.regular.iconSize, 16)
    }
}
