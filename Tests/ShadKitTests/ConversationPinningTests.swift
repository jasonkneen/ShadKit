import XCTest
@testable import AIElementsUI

final class ConversationStyleTests: XCTestCase {

    func testStandardConversationStylePreservesExistingMetrics() {
        XCTAssertEqual(
            AIConversationStyle.standard,
            AIConversationStyle(
                itemSpacing: 32,
                horizontalPadding: 16,
                verticalPadding: 16,
                bottomTolerance: 8
            )
        )
    }

    func testCompactConversationStyleOnlyReducesTurnSpacing() {
        XCTAssertEqual(
            AIConversationStyle.compact,
            AIConversationStyle(
                itemSpacing: 16,
                horizontalPadding: 16,
                verticalPadding: 16,
                bottomTolerance: 8
            )
        )
    }

    func testStandardMessageStylePreservesExistingBubbleInsets() {
        XCTAssertEqual(
            AIMessageStyle.standard,
            AIMessageStyle(bubbleHorizontalPadding: 16, bubbleVerticalPadding: 12)
        )
    }

    func testCompactMessageStyleOnlyReducesVerticalBubbleInset() {
        XCTAssertEqual(
            AIMessageStyle.compact,
            AIMessageStyle(bubbleHorizontalPadding: 16, bubbleVerticalPadding: 8)
        )
    }
}

final class ConversationPinningTests: XCTestCase {

    func testInitialOverflowingContentRequestsTheBottom() {
        var pinning = AIConversationPinningState()

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: 0, contentHeight: 600, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .scrollToBottom
        )
        XCTAssertTrue(pinning.isFollowing)
        XCTAssertTrue(pinning.isScrollPending)

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -300, contentHeight: 600, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertTrue(pinning.isFollowing)
        XCTAssertFalse(pinning.isScrollPending)
    }

    func testManualHistoryScrollUnpinsAndSuppressesStreamingScrolls() {
        var pinning = pinnedState()

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -240, contentHeight: 600, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertFalse(pinning.isFollowing)
        XCTAssertFalse(pinning.isScrollPending)

        XCTAssertEqual(pinning.contentDidChange(), .none)
        XCTAssertFalse(pinning.isFollowing)
    }

    func testContentGrowthWhileUnpinnedDoesNotYankTheTranscript() {
        var pinning = pinnedState()
        _ = pinning.geometryDidChange(
            geometry(contentMinY: -240, contentHeight: 600, viewportHeight: 300),
            bottomTolerance: 8
        )

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -240, contentHeight: 640, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertFalse(pinning.isFollowing)
        XCTAssertFalse(pinning.isScrollPending)
    }

    func testManualScrollWinsWhenContentGrowsInTheSameLayoutPass() {
        var pinning = pinnedState()

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -240, contentHeight: 640, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertFalse(pinning.isFollowing)
        XCTAssertFalse(pinning.isScrollPending)
        XCTAssertEqual(pinning.contentDidChange(), .none)
    }

    func testReturningWithinToleranceRepins() {
        var pinning = pinnedState()
        _ = pinning.geometryDidChange(
            geometry(contentMinY: -240, contentHeight: 600, viewportHeight: 300),
            bottomTolerance: 8
        )

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -293, contentHeight: 600, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertTrue(pinning.isFollowing)
        XCTAssertFalse(pinning.isScrollPending)
    }

    func testContentGrowthWhileFollowingRequestsTheNewBottom() {
        var pinning = pinnedState()

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -300, contentHeight: 640, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .scrollToBottom
        )
        XCTAssertTrue(pinning.isFollowing)
        XCTAssertTrue(pinning.isScrollPending)

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -340, contentHeight: 640, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertFalse(pinning.isScrollPending)
    }

    func testGrowthReissuesScrollWhenStreamTokenArrivedBeforeLayout() {
        var pinning = pinnedState()

        XCTAssertEqual(pinning.contentDidChange(), .scrollToBottom)
        XCTAssertFalse(
            pinning.isScrollPending,
            "a token-only request must not suppress a later layout observation"
        )

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -300, contentHeight: 640, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .scrollToBottom,
            "the first request may have targeted the pre-layout anchor"
        )
    }

    func testViewportResizeKeepsFollowingAndRequestsTheBottom() {
        var pinning = pinnedState()

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -300, contentHeight: 600, viewportHeight: 240),
                bottomTolerance: 8
            ),
            .scrollToBottom
        )
        XCTAssertTrue(pinning.isFollowing)

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -360, contentHeight: 600, viewportHeight: 240),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertTrue(pinning.isFollowing)
        XCTAssertFalse(pinning.isScrollPending)
    }

    func testViewportResizeWhileUnpinnedDoesNotYankTheTranscript() {
        var pinning = pinnedState()
        _ = pinning.geometryDidChange(
            geometry(contentMinY: -240, contentHeight: 600, viewportHeight: 300),
            bottomTolerance: 8
        )

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -240, contentHeight: 600, viewportHeight: 240),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertFalse(pinning.isFollowing)
    }

    func testExplicitScrollToLatestRepinsAndRequestsScroll() {
        var pinning = pinnedState()
        _ = pinning.geometryDidChange(
            geometry(contentMinY: -240, contentHeight: 600, viewportHeight: 300),
            bottomTolerance: 8
        )

        XCTAssertEqual(pinning.scrollToLatest(), .scrollToBottom)
        XCTAssertTrue(pinning.isFollowing)
        XCTAssertTrue(pinning.isScrollPending)
    }

    func testManualMovementCanCancelAnExplicitPendingScroll() {
        var pinning = pinnedState()
        _ = pinning.geometryDidChange(
            geometry(contentMinY: -240, contentHeight: 600, viewportHeight: 300),
            bottomTolerance: 8
        )
        _ = pinning.scrollToLatest()

        XCTAssertEqual(
            pinning.geometryDidChange(
                geometry(contentMinY: -200, contentHeight: 600, viewportHeight: 300),
                bottomTolerance: 8
            ),
            .none
        )
        XCTAssertFalse(pinning.isFollowing)
        XCTAssertFalse(pinning.isScrollPending)
    }

    private func pinnedState() -> AIConversationPinningState {
        var pinning = AIConversationPinningState()
        _ = pinning.geometryDidChange(
            geometry(contentMinY: -300, contentHeight: 600, viewportHeight: 300),
            bottomTolerance: 8
        )
        return pinning
    }

    private func geometry(
        contentMinY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat
    ) -> AIConversationGeometry {
        AIConversationGeometry(
            contentMinY: contentMinY,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        )
    }
}
