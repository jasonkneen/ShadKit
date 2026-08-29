import SwiftUI
import XCTest
@testable import ShadcnUI

final class OverlayTrailingAlignmentTests: XCTestCase {
    func testTrailingOriginAccountsForPanelWidth() {
        let trigger = CGRect(x: 270, y: 20, width: 50, height: 24)
        let origin = ShadcnOverlayPlacement.origin(
            trigger: trigger,
            edge: .bottom,
            alignment: .trailing,
            gap: 4,
            contentHeight: nil,
            contentWidth: 220
        )

        XCTAssertEqual(origin.x, 100)
        XCTAssertEqual(origin.y, 48)
    }

    func testCenterOriginAccountsForPanelWidth() {
        let trigger = CGRect(x: 270, y: 20, width: 50, height: 24)
        let origin = ShadcnOverlayPlacement.origin(
            trigger: trigger,
            edge: .bottom,
            alignment: .center,
            gap: 4,
            contentHeight: nil,
            contentWidth: 220
        )

        XCTAssertEqual(origin.x, 185)
    }
}
