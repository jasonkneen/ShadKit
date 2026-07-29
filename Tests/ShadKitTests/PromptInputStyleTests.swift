import XCTest
@testable import AIElementsUI
@testable import ShadcnUI

/// The three provider composers differ *only* in `AIPromptInputStyle`. If the
/// presets drift, ChatGPT/Grok/Claude stop looking like themselves.
final class PromptInputStyleTests: XCTestCase {

    func testDefaultMatchesTheAIElementsComposer() {
        let style = AIPromptInputStyle.default
        XCTAssertNil(style.cornerRadius, "nil defers to the theme's rounded-md")
        XCTAssertNil(style.background)
        XCTAssertEqual(style.minTextHeight, 64)   // min-h-16
        XCTAssertEqual(style.maxTextHeight, 192)  // max-h-48
        XCTAssertFalse(style.usesLargeText)
        XCTAssertFalse(style.submitIsCircular)
    }

    func testPillMatchesChatGPTAndGrok() {
        let style = AIPromptInputStyle.pill
        XCTAssertEqual(style.cornerRadius, 28)                    // rounded-[28px]
        XCTAssertEqual(style.textFieldHorizontalPadding, 20)      // px-5
        XCTAssertEqual(style.footerPadding, 10)                   // p-2.5
        XCTAssertTrue(style.usesLargeText)                        // md:text-base
        XCTAssertTrue(style.submitIsCircular)
    }

    func testCompactRestsAtOneLine() {
        let style = AIPromptInputStyle.compact
        XCTAssertLessThan(
            style.minTextHeight, AIPromptInputStyle.default.minTextHeight,
            "a sidebar composer must not open as a tall empty box")
        XCTAssertLessThan(style.maxTextHeight, AIPromptInputStyle.default.maxTextHeight)
        XCTAssertLessThan(style.footerPadding, AIPromptInputStyle.default.footerPadding)
    }

    func testEveryPresetGrowsBeforeItScrolls() {
        for style in [AIPromptInputStyle.default, .pill, .compact] {
            XCTAssertLessThan(
                style.minTextHeight, style.maxTextHeight,
                "resting height must be under the scroll threshold")
        }
    }

    func testChatStatusMapsOntoTheComposer() {
        // `ChatStatus` from the AI SDK drives which glyph the submit shows.
        XCTAssertEqual(AIChatStatus.ready.promptStatus, .ready)
        XCTAssertEqual(AIChatStatus.submitted.promptStatus, .submitted)
        XCTAssertEqual(AIChatStatus.streaming.promptStatus, .streaming)
        XCTAssertEqual(AIChatStatus.error.promptStatus, .error)
    }

    func testStatusRawValuesMatchTheSDK() {
        XCTAssertEqual(AIChatStatus.submitted.rawValue, "submitted")
        XCTAssertEqual(AIChatStatus.streaming.rawValue, "streaming")
        XCTAssertEqual(AIPromptStatus.ready.rawValue, "ready")
        XCTAssertEqual(Set(AIPromptStatus.allCases.map(\.rawValue)),
                       ["ready", "submitted", "streaming", "error"])
    }

    func testTailwindStatusSwatchesAreDistinct() {
        // The five hardcoded status colours must not collapse into each other.
        let swatches = [
            AITailwindColor.yellow600, AITailwindColor.blue600,
            AITailwindColor.green600, AITailwindColor.red600,
            AITailwindColor.orange600,
        ]
        XCTAssertEqual(Set(swatches.map(String.init(describing:))).count, swatches.count)
    }
}
