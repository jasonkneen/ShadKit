import XCTest
@testable import AIElementsUI

/// Guards `AIQueueStrip.pendingCount`, the pure count behind the strip's
/// collapsed header.
final class QueueStripTests: XCTestCase {

    func testCountsOnlyPendingUncompletedItems() {
        let items = [
            AIQueueItem(title: "Queued", isPending: true),
            AIQueueItem(title: "Also queued", isPending: true),
            AIQueueItem(title: "Done", isCompleted: true, isPending: true),
            AIQueueItem(title: "Not queued yet"),
        ]
        XCTAssertEqual(AIQueueStrip.pendingCount(items), 2)
    }

    func testEmptyListCountsZero() {
        XCTAssertEqual(AIQueueStrip.pendingCount([]), 0)
    }

    func testCompletedPendingItemIsNotCounted() {
        let items = [AIQueueItem(title: "Done", isCompleted: true, isPending: true)]
        XCTAssertEqual(AIQueueStrip.pendingCount(items), 0)
    }

    func testDefaultIsPendingIsFalse() {
        let item = AIQueueItem(title: "Legacy caller")
        XCTAssertFalse(item.isPending)
    }
}
