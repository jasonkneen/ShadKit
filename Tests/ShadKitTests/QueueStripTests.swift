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
            // No explicit isPending: resolves to !isCompleted, so this one
            // counts too — a caller that never opts in still reports a
            // correct pending count instead of the fixed `false` 0.3.0
            // shipped.
            AIQueueItem(title: "Not queued yet"),
        ]
        XCTAssertEqual(AIQueueStrip.pendingCount(items), 3)
    }

    func testEmptyListCountsZero() {
        XCTAssertEqual(AIQueueStrip.pendingCount([]), 0)
    }

    func testCompletedPendingItemIsNotCounted() {
        let items = [AIQueueItem(title: "Done", isCompleted: true, isPending: true)]
        XCTAssertEqual(AIQueueStrip.pendingCount(items), 0)
    }

    func testDefaultIsPendingResolvesFromIsCompleted() {
        XCTAssertTrue(AIQueueItem(title: "Not started").isPending)
        XCTAssertFalse(AIQueueItem(title: "Already done", isCompleted: true).isPending)
    }

    func testExplicitIsPendingOverridesTheResolvedDefault() {
        // A cancelled-but-uncompleted item is the case explicit isPending
        // exists for: !isCompleted would say "pending", but it isn't.
        let item = AIQueueItem(title: "Cancelled", isCompleted: false, isPending: false)
        XCTAssertFalse(item.isPending)
    }
}
