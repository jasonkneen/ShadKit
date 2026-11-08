import XCTest
@testable import ShadcnUI

final class DockMagnificationTests: XCTestCase {
    private let m = ShadcnDockMetrics()
    private let kinds: [ShadcnDockItem.Kind] = [.item, .item, .item, .separator, .item]

    func testCosineFalloffPeaksUnderThePointerAndEasesToRest() {
        XCTAssertEqual(ShadcnDockMetrics.scale(distance: 0, maxScale: 1.6, range: 100), 1.6, accuracy: 1e-9)
        XCTAssertEqual(ShadcnDockMetrics.scale(distance: 50, maxScale: 1.6, range: 100), 1.3, accuracy: 1e-9)
        XCTAssertEqual(ShadcnDockMetrics.scale(distance: 100, maxScale: 1.6, range: 100), 1)
        XCTAssertEqual(ShadcnDockMetrics.scale(distance: 250, maxScale: 1.6, range: 100), 1)
        XCTAssertEqual(
            ShadcnDockMetrics.scale(distance: -30, maxScale: 1.6, range: 100),
            ShadcnDockMetrics.scale(distance: 30, maxScale: 1.6, range: 100))
    }

    func testRestingLayoutHasNoSwell() {
        XCTAssertEqual(m.widths(kinds, pointer: nil), [36, 36, 36, m.separatorWidth, 36])
        XCTAssertEqual(m.width(kinds, pointer: nil), m.restingWidth(kinds))
    }

    func testItemUnderPointerIsLargestAndNeighboursFollow() {
        let centers = m.restingCenters(kinds)
        let w = m.widths(kinds, pointer: centers[1])
        XCTAssertEqual(w[1], m.iconSize * m.maxScale, accuracy: 1e-9)
        XCTAssertGreaterThan(w[0], m.iconSize)
        XCTAssertLessThan(w[0], w[1])
        XCTAssertEqual(w[0], w[2], accuracy: 1e-9, "symmetric about the pointer")
    }

    func testSeparatorsNeverScale() {
        let centers = m.restingCenters(kinds)
        XCTAssertEqual(m.widths(kinds, pointer: centers[3])[3], m.separatorWidth)
    }

    func testReservedWidthCoversEveryPointerPosition() {
        let maxWidth = m.maxWidth(kinds)
        for p in stride(from: 0, through: m.restingWidth(kinds), by: 1) {
            XCTAssertLessThanOrEqual(m.width(kinds, pointer: p), maxWidth + 0.5)
        }
    }

    func testBarGrowsAroundThePointerAndStaysInsideItsFrame() {
        let container = m.reservedWidth(kinds)
        XCTAssertGreaterThanOrEqual(container, m.maxWidth(kinds))
        let restLeft = (container - m.restingWidth(kinds)) / 2
        XCTAssertEqual(m.barOffset(kinds, pointer: nil), restLeft, accuracy: 1e-9)
        for p in stride(from: 0, through: m.restingWidth(kinds), by: 3) {
            let offset = m.barOffset(kinds, pointer: p)
            XCTAssertGreaterThanOrEqual(offset, 0)
            XCTAssertLessThanOrEqual(offset + m.width(kinds, pointer: p), container + 0.5)
        }
        // Anywhere along the bar, the spot under the cursor does not move.
        for p in stride(from: 0, through: m.restingWidth(kinds), by: 5) {
            XCTAssertEqual(m.barOffset(kinds, pointer: p) + m.mappedPosition(kinds, pointer: p),
                           restLeft + p, accuracy: 0.5, "pointer \(p)")
        }
    }
}
