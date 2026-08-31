import XCTest
@testable import AIElementsUI

/// Following the bottom used to start a fresh 0.2s `scrollTo` animation on
/// every streamed token. Each one interrupted the last, which is what the
/// transcript looked like: jumpy rather than smooth.
///
/// The rule: growth of the in-flight text pins without animation, structural
/// changes (a turn lands, a tool deck appears) still glide.
final class ConversationFollowAnimationTests: XCTestCase {

    private func token(items: Int = 1, stream: Int = 0, extra: Int = 0) -> AIConversationToken {
        AIConversationToken(itemCount: items, streamLength: stream, extra: extra)
    }

    func testStreamGrowthFollowsWithoutAnimation() {
        XCTAssertFalse(
            AIConversationToken.animatesFollow(
                from: token(items: 3, stream: 120),
                to: token(items: 3, stream: 121)))
    }

    func testNewTurnAnimates() {
        XCTAssertTrue(
            AIConversationToken.animatesFollow(
                from: token(items: 3, stream: 400),
                to: token(items: 4, stream: 0)))
    }

    func testToolDeckChangeAnimates() {
        XCTAssertTrue(
            AIConversationToken.animatesFollow(
                from: token(items: 3, extra: 1),
                to: token(items: 3, extra: 2)))
    }

    func testStreamShrinkingDoesNotAnimate() {
        // Clearing the live tail as the turn is committed happens in the same
        // beat as the append; the append is what earns the animation.
        XCTAssertFalse(
            AIConversationToken.animatesFollow(
                from: token(items: 3, stream: 400),
                to: token(items: 3, stream: 0)))
    }

    func testAnOpaqueTokenStillAnimates() {
        // Callers that have not adopted the structured token keep the old
        // behaviour rather than silently losing their scroll animation.
        XCTAssertTrue(
            AIConversationToken.animatesFollow(
                from: .opaque(AnyHashable(1)),
                to: .opaque(AnyHashable(2))))
    }

    func testStructuredTokenIsEquatableOnAllFields() {
        XCTAssertEqual(token(items: 2, stream: 3, extra: 4), token(items: 2, stream: 3, extra: 4))
        XCTAssertNotEqual(token(items: 2, stream: 3, extra: 4), token(items: 2, stream: 3, extra: 5))
    }
}
