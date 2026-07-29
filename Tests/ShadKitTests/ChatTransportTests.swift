import XCTest
@testable import AIElementsUI

/// Streaming behaviours a real backend produces that the happy-path tests miss.
@MainActor
final class ChatTransportTests: XCTestCase {

    private func settle(_ chat: AIChat, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while chat.status != .ready && chat.status != .error {
            if Date() > deadline { return XCTFail("chat never settled") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testAnEmptyStreamStillSettles() async throws {
        // A backend that returns nothing must not leave the composer spinning.
        let chat = AIChat(transport: AIMockChatTransport(tokenDelay: 0) { _ in [.finish] })
        chat.sendMessage("go")
        try await settle(chat)
        XCTAssertEqual(chat.status, .ready)
    }

    func testReasoningAndTextCoalesceSeparately() async throws {
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [.reasoningDelta("think "), .reasoningDelta("more"),
             .textDelta("say "), .textDelta("this"), .finish]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        try await settle(chat)

        let parts = try XCTUnwrap(chat.messages.last?.parts)
        XCTAssertEqual(parts.count, 2, "reasoning and prose must not merge")
        guard case let .reasoning(_, thought, _) = parts[0] else { return XCTFail() }
        XCTAssertEqual(thought, "think more")
        XCTAssertEqual(chat.messages.last?.text, "say this")
    }

    func testTextAfterAToolCallStartsANewPart() async throws {
        // A tool between two prose runs must break the coalescing.
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [.textDelta("before"),
             .toolCall(UIToolPart(id: "t", type: "tool-x", state: .inputAvailable)),
             .textDelta("after"), .finish]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        try await settle(chat)

        let parts = try XCTUnwrap(chat.messages.last?.parts)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(chat.messages.last?.text, "before\n\nafter")
    }

    func testSourcesAppendAsTheyArrive() async throws {
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [.source(AISource(title: "one")), .source(AISource(title: "two")),
             .textDelta("body"), .finish]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        try await settle(chat)

        let sources = try XCTUnwrap(chat.messages.last).parts.compactMap { part -> AISource? in
            if case let .source(source) = part { return source }
            return nil
        }
        XCTAssertEqual(sources.map(\.title), ["one", "two"])
    }

    func testResultForAnUnknownToolIsIgnored() async throws {
        // A stray result must not fabricate a card.
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [.toolResult(id: "ghost", output: "x", errorText: nil), .textDelta("hi"), .finish]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        try await settle(chat)

        let tools = try XCTUnwrap(chat.messages.last).parts.filter {
            if case .tool = $0 { return true }
            return false
        }
        XCTAssertTrue(tools.isEmpty)
    }

    func testSendIsRejectedWhileStreaming() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "a b c d", tokenDelay: 0.05))
        chat.sendMessage("first")
        chat.sendMessage("second")
        XCTAssertEqual(
            chat.messages.filter { $0.role == .user }.count, 1,
            "a second send mid-turn must be dropped, not queued silently")
        chat.stop()
    }

    func testRegenerateWithNoHistoryIsANoOp() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "x", tokenDelay: 0))
        chat.regenerate()
        XCTAssertTrue(chat.messages.isEmpty)
        XCTAssertEqual(chat.status, .ready)
    }

    func testStopBeforeAnythingArrivesLeavesNoEmptyTurn() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "a b", tokenDelay: 0.5))
        chat.sendMessage("go")
        chat.stop()
        XCTAssertEqual(chat.status, .ready)
        XCTAssertEqual(chat.messages.count, 1, "only the user turn should remain")
    }

    func testOptionsTravelWithTheRequest() async throws {
        var seen: AIChatRequestOptions?
        struct Probe: AIChatTransport {
            let onSend: @Sendable (AIChatRequestOptions) -> Void
            func send(
                messages: [UIMessage], options: AIChatRequestOptions
            ) -> AsyncThrowingStream<AIChatChunk, Error> {
                onSend(options)
                return AsyncThrowingStream { $0.finish() }
            }
        }
        let chat = AIChat(transport: Probe { seen = $0 })
        chat.options = AIChatRequestOptions(model: "opus", webSearch: true)
        chat.sendMessage("go")
        try await settle(chat)

        XCTAssertEqual(seen?.model, "opus")
        XCTAssertEqual(seen?.webSearch, true)
    }
}
