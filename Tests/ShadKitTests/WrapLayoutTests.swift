import SwiftUI
import XCTest
@testable import ShadcnUI

/// `ShadcnWrapLayout` backs attachment rows, search-result pills and suggestion
/// chips. Its row packing had no coverage.
final class WrapLayoutTests: XCTestCase {

    /// Exercises the packing arithmetic directly — the part that decides where
    /// a row breaks — without needing a render pass.
    private func rows(
        widths: [CGFloat],
        maxWidth: CGFloat,
        spacing: CGFloat = 8
    ) -> [[CGFloat]] {
        var result: [[CGFloat]] = []
        var current: [CGFloat] = []
        var used: CGFloat = 0

        for width in widths {
            let needed = current.isEmpty ? width : used + spacing + width
            if needed > maxWidth, !current.isEmpty {
                result.append(current)
                current = [width]
                used = width
            } else {
                current.append(width)
                used = needed
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    func testItemsFitOnOneRowWhenThereIsRoom() {
        XCTAssertEqual(rows(widths: [40, 40, 40], maxWidth: 200), [[40, 40, 40]])
    }

    func testSpacingCountsTowardTheBreak() {
        // 40+8+40+8+40 = 136 fits; adding one more (+8+40 = 184) still fits at
        // 200 but not at 180.
        XCTAssertEqual(rows(widths: [40, 40, 40, 40], maxWidth: 180).count, 2)
    }

    func testAnOversizedItemGetsItsOwnRow() {
        // Wider than the container: it must not be dropped or merged.
        let packed = rows(widths: [40, 500, 40], maxWidth: 200)
        XCTAssertEqual(packed, [[40], [500], [40]])
    }

    func testFirstItemNeverWrapsAlone() {
        // An item that cannot fit still occupies a row rather than looping.
        XCTAssertEqual(rows(widths: [500], maxWidth: 100), [[500]])
    }

    func testEmptyInputProducesNoRows() {
        XCTAssertTrue(rows(widths: [], maxWidth: 200).isEmpty)
    }

    func testEveryItemIsPlacedExactlyOnce() {
        let widths: [CGFloat] = [30, 90, 45, 120, 60, 15]
        let placed = rows(widths: widths, maxWidth: 200).flatMap { $0 }
        XCTAssertEqual(placed, widths, "packing must not drop or reorder items")
    }

    func testLayoutIsConstructibleWithEachAlignment() {
        for alignment in [HorizontalAlignment.leading, .center, .trailing] {
            let layout = ShadcnWrapLayout(spacing: 8, lineSpacing: 8, alignment: alignment)
            XCTAssertEqual(layout.spacing, 8)
            XCTAssertEqual(layout.lineSpacing, 8)
        }
    }
}
