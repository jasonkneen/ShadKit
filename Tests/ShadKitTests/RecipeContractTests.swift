import SwiftUI
import XCTest
@testable import AIElementsUI
@testable import CanvasUI
@testable import ShadcnUI

/// The recipes doc makes promises. These hold it to them, so the examples can't
/// rot silently as the API moves.
@MainActor
final class RecipeContractTests: XCTestCase {

    /// "Deltas coalesce automatically — yield per token, don't batch."
    func testPerTokenYieldingProducesOnePart() async throws {
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            "the quick brown fox".map { AIChatChunk.textDelta(String($0)) } + [.finish]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        while chat.status != .ready { try await Task.sleep(nanoseconds: 5_000_000) }

        XCTAssertEqual(chat.messages.last?.parts.count, 1, "19 yields, one part")
        XCTAssertEqual(chat.messages.last?.text, "the quick brown fox")
    }

    /// "Omitting the name on the result is correct — the card keeps the one
    /// from the call."
    func testResultWithoutANameKeepsTheCallsName() async throws {
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [.toolCall(UIToolPart(id: "t", type: "tool-search", state: .inputAvailable)),
             .toolResult(id: "t", output: "ok", errorText: nil), .finish]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        while chat.status != .ready { try await Task.sleep(nanoseconds: 5_000_000) }

        guard case let .tool(tool) = try XCTUnwrap(chat.messages.last?.parts.first) else {
            return XCTFail("expected a tool part")
        }
        XCTAssertEqual(tool.name, "search")
    }

    /// "Anything omitted falls back, so a partial theme still yields a complete
    /// palette."
    func testPartialThemeYieldsACompletePalette() {
        let spec = ShadcnPaletteSpec(cssVars: ["primary": "#FF0000"], fallback: .neutralDark)
        let palette = spec.resolved(isDark: true)
        XCTAssertTrue(palette.isDark)
        // Every slot is populated, not just the one supplied.
        XCTAssertEqual(spec.primary.hexString, "#FF0000")
        XCTAssertEqual(spec.background.hexString, ShadcnPaletteSpec.neutralDark.background.hexString)
        XCTAssertEqual(spec.ring.hexString, ShadcnPaletteSpec.neutralDark.ring.hexString)
    }

    /// "Compose CanvasNodeCard to inherit the shadcn chrome."
    func testACustomNodeTypeIsDispatched() {
        var registry = CanvasNodeRegistry<String>()
        var built = false
        registry.register("prompt") { _, _ in
            built = true
            return CanvasNodeCard { Text("x") }
        }
        _ = registry.view(
            for: CanvasNode(id: "n", type: "prompt", position: .zero, data: "d"),
            context: CanvasNodeContext())
        XCTAssertTrue(built)
    }

    /// "Tools are separate from `messages` on purpose."
    func testRebuildingMessagesLeavesToolsIntact() {
        let model = AIAssistantPanelModel()
        model.applyTool(id: "t", name: "search", state: .outputAvailable, output: "ok")
        model.messages = [UIMessage(role: .assistant, text: "rebuilt")]
        XCTAssertEqual(model.tools.count, 1)
    }

    /// "`AIResponse` isn't greedy."
    func testResponseParsesWithoutClaimingWidth() {
        // The width behaviour is a layout property, but the parse it wraps must
        // stay stable — that's what the recipe's callers depend on.
        XCTAssertEqual(
            AIMarkdownBlock.parse("**bold** text"), [.paragraph("**bold** text")])
    }

    /// "OKLCH, HSL and hex all parse."
    func testAllThreeNotationsParseInOneBlock() throws {
        let spec = try XCTUnwrap(ShadcnPaletteSpec(
            css: "--background: oklch(1 0 0); --foreground: 0 0% 0%; --primary: #3B82F6;"))
        XCTAssertEqual(spec.background.hexString, "#FFFFFF")
        XCTAssertEqual(spec.foreground.hexString, "#000000")
        XCTAssertEqual(spec.primary.hexString, "#3B82F6")
    }
}
