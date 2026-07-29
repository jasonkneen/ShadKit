import XCTest
@testable import AIElementsUI

@MainActor
final class ChatRuntimeTests: XCTestCase {

    /// Drives the chat until `status` returns to ready (or errors), so tests
    /// don't race the stream.
    private func settle(_ chat: AIChat, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while chat.status != .ready && chat.status != .error {
            if Date() > deadline { XCTFail("chat never settled"); return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testSendMessageAppendsUserTurnAndClearsInput() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "hi there", tokenDelay: 0))
        chat.input = "hello"
        chat.sendMessage()

        XCTAssertEqual(chat.messages.first?.role, .user)
        XCTAssertEqual(chat.messages.first?.text, "hello")
        XCTAssertTrue(chat.input.isEmpty, "input should clear once sent")

        try await settle(chat)
    }

    func testStreamedDeltasCoalesceIntoOneTextPart() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "one two three", tokenDelay: 0))
        chat.sendMessage("go")
        try await settle(chat)

        let reply = try XCTUnwrap(chat.messages.last)
        XCTAssertEqual(reply.role, .assistant)
        // Three word-deltas must merge into a single part, not three.
        XCTAssertEqual(reply.parts.count, 1)
        XCTAssertEqual(reply.text.trimmingCharacters(in: .whitespaces), "one two three")
    }

    func testStatusTransitions() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "a b", tokenDelay: 0.02))
        XCTAssertEqual(chat.status, .ready)

        chat.sendMessage("go")
        XCTAssertEqual(chat.status, .submitted, "status is submitted before the first chunk")

        try await settle(chat)
        XCTAssertEqual(chat.status, .ready)
    }

    func testEmptyInputIsIgnored() {
        let chat = AIChat(transport: AIMockChatTransport(reply: "x", tokenDelay: 0))
        chat.input = "   \n "
        chat.sendMessage()
        XCTAssertTrue(chat.messages.isEmpty)
    }

    func testStopHaltsStreamingAndKeepsPartialText() async throws {
        let chat = AIChat(
            transport: AIMockChatTransport(reply: "a b c d e f g h", tokenDelay: 0.05)
        )
        chat.sendMessage("go")

        // Let a couple of tokens land, then cancel.
        try await Task.sleep(nanoseconds: 150_000_000)
        chat.stop()

        XCTAssertEqual(chat.status, .ready)
        let text = chat.messages.last?.text ?? ""
        XCTAssertFalse(text.isEmpty, "partial text should survive a stop")
        XCTAssertLessThan(text.count, 16, "stop should have cut the stream short")
    }

    func testRegenerateReplacesTheLastAssistantTurn() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "first", tokenDelay: 0))
        chat.sendMessage("go")
        try await settle(chat)
        XCTAssertEqual(chat.messages.count, 2)

        chat.regenerate()
        try await settle(chat)

        XCTAssertEqual(chat.messages.count, 2, "regenerate must not stack replies")
        XCTAssertEqual(chat.messages.first?.role, .user)
        XCTAssertEqual(chat.messages.last?.role, .assistant)
    }

    func testToolCallThenResultUpdatesInPlace() async throws {
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [
                .toolCall(
                    UIToolPart(id: "t1", type: "tool-search", state: .inputAvailable, input: "{}")
                ),
                .toolResult(id: "t1", output: "{\"ok\":true}", errorText: nil),
                .finish,
            ]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        try await settle(chat)

        let parts = try XCTUnwrap(chat.messages.last?.parts)
        XCTAssertEqual(parts.count, 1, "the result must update the call, not append")
        guard case let .tool(tool) = parts[0] else {
            return XCTFail("expected a tool part")
        }
        XCTAssertEqual(tool.state, .outputAvailable)
        XCTAssertEqual(tool.output, "{\"ok\":true}")
        XCTAssertEqual(tool.name, "search", "name drops the tool- prefix")
    }

    func testToolErrorMarksTheCallFailed() async throws {
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [
                .toolCall(UIToolPart(id: "t1", type: "tool-run", state: .inputAvailable)),
                .toolResult(id: "t1", output: nil, errorText: "boom"),
                .finish,
            ]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        try await settle(chat)

        guard case let .tool(tool) = try XCTUnwrap(chat.messages.last?.parts.first) else {
            return XCTFail("expected a tool part")
        }
        XCTAssertEqual(tool.state, .outputError)
        XCTAssertEqual(tool.errorText, "boom")
    }

    func testReasoningDurationIsStamped() async throws {
        let transport = AIMockChatTransport(tokenDelay: 0) { _ in
            [.reasoningDelta("thinking"), .reasoningDone(duration: 7), .finish]
        }
        let chat = AIChat(transport: transport)
        chat.sendMessage("go")
        try await settle(chat)

        guard case let .reasoning(_, text, duration) =
            try XCTUnwrap(chat.messages.last?.parts.first)
        else {
            return XCTFail("expected a reasoning part")
        }
        XCTAssertEqual(text, "thinking")
        XCTAssertEqual(duration, 7)
    }

    func testTransportFailureSurfacesAsError() async throws {
        struct Boom: Error {}
        struct FailingTransport: AIChatTransport {
            func send(
                messages: [UIMessage],
                options: AIChatRequestOptions
            ) -> AsyncThrowingStream<AIChatChunk, Error> {
                AsyncThrowingStream { continuation in
                    continuation.yield(.textDelta("partial"))
                    continuation.finish(throwing: Boom())
                }
            }
        }

        let chat = AIChat(transport: FailingTransport())
        chat.sendMessage("go")
        try await settle(chat)

        XCTAssertEqual(chat.status, .error)
        XCTAssertNotNil(chat.error)
    }

    func testClearResetsEverything() async throws {
        let chat = AIChat(transport: AIMockChatTransport(reply: "hi", tokenDelay: 0))
        chat.sendMessage("go")
        try await settle(chat)

        chat.clear()
        XCTAssertTrue(chat.messages.isEmpty)
        XCTAssertNil(chat.error)
        XCTAssertEqual(chat.status, .ready)
    }

    // MARK: - Model shape

    func testMessageTextJoinsOnlyTextParts() {
        let message = UIMessage(
            role: .assistant,
            parts: [
                .text("alpha"),
                .reasoning("hidden"),
                .text("beta"),
            ]
        )
        XCTAssertEqual(message.text, "alpha\n\nbeta")
    }

    func testChatStatusMapsToPromptStatus() {
        XCTAssertEqual(AIChatStatus.streaming.promptStatus, .streaming)
        XCTAssertEqual(AIChatStatus.ready.promptStatus, .ready)
        XCTAssertEqual(AIChatStatus.submitted.promptStatus, .submitted)
        XCTAssertEqual(AIChatStatus.error.promptStatus, .error)
    }
}
