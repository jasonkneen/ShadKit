import XCTest
@testable import AIElementsUI

/// `UIMessage` / `UIMessagePart` mirror the AI SDK's shape. Consumers port
/// against these names, so the mapping is worth pinning.
final class UIMessageTests: XCTestCase {

    func testToolStateRawValuesMatchTheSDKStrings() {
        // These cross the wire from Claude, ACP and Codex; a rename breaks them.
        XCTAssertEqual(AIToolState.inputStreaming.rawValue, "input-streaming")
        XCTAssertEqual(AIToolState.inputAvailable.rawValue, "input-available")
        XCTAssertEqual(AIToolState.approvalRequested.rawValue, "approval-requested")
        XCTAssertEqual(AIToolState.approvalResponded.rawValue, "approval-responded")
        XCTAssertEqual(AIToolState.outputAvailable.rawValue, "output-available")
        XCTAssertEqual(AIToolState.outputError.rawValue, "output-error")
        XCTAssertEqual(AIToolState.outputDenied.rawValue, "output-denied")
    }

    func testEveryToolStateHasLabelAndIcon() {
        for state in AIToolState.allCases {
            XCTAssertFalse(state.label.isEmpty, "\(state) needs badge copy")
            XCTAssertFalse(state.systemImage.isEmpty, "\(state) needs a glyph")
        }
    }

    func testOnlyResolvedStatesCarryAColouredIcon() {
        // The in-flight states inherit the badge colour; the rest are tinted.
        XCTAssertNil(AIToolState.inputStreaming.iconTint)
        XCTAssertNil(AIToolState.inputAvailable.iconTint)
        for state in [AIToolState.approvalRequested, .approvalResponded,
                      .outputAvailable, .outputError, .outputDenied] {
            XCTAssertNotNil(state.iconTint, "\(state) should be tinted")
        }
    }

    func testToolNameDropsTheTypePrefix() {
        // `tool-search_codebase` renders as `search_codebase`.
        XCTAssertEqual(
            UIToolPart(type: "tool-search_codebase", state: .outputAvailable).name,
            "search_codebase")
    }

    func testHyphenatedToolNamesSurviveTheSplit() {
        XCTAssertEqual(
            UIToolPart(type: "tool-read-file", state: .outputAvailable).name, "read-file")
    }

    func testTypeWithoutAPrefixIsUsedWhole() {
        XCTAssertEqual(UIToolPart(type: "bare", state: .outputAvailable).name, "bare")
    }

    func testPartIdentityFollowsThePayload() {
        let tool = UIToolPart(id: "t1", type: "tool-x", state: .outputAvailable)
        XCTAssertEqual(UIMessagePart.tool(tool).id, "t1")

        let source = AISource(id: "s1", title: "shadcn")
        XCTAssertEqual(UIMessagePart.source(source).id, "s1")

        let file = UIFilePart(id: "f1", filename: "a.png")
        XCTAssertEqual(UIMessagePart.file(file).id, "f1")
    }

    func testTextContentOnlyExistsForProseParts() {
        XCTAssertEqual(UIMessagePart.text(id: "1", "hello").textContent, "hello")
        XCTAssertEqual(UIMessagePart.reasoning(id: "2", "thinking").textContent, "thinking")
        XCTAssertNil(UIMessagePart.stepStart(id: "3").textContent)
        XCTAssertNil(
            UIMessagePart.tool(UIToolPart(type: "tool-x", state: .outputAvailable)).textContent)
    }

    func testImageAttachmentsAreDetectedByMediaType() {
        XCTAssertTrue(UIFilePart(filename: "a.png", mediaType: "image/png").isImage)
        XCTAssertFalse(UIFilePart(filename: "a.pdf", mediaType: "application/pdf").isImage)
        XCTAssertFalse(UIFilePart(filename: "a.png").isImage, "no media type, no assumption")
    }

    func testConvenienceInitBuildsASingleTextPart() {
        let message = UIMessage(role: .user, text: "hi")
        XCTAssertEqual(message.parts.count, 1)
        XCTAssertEqual(message.text, "hi")
    }

    func testRolesCoverTheSDKSet() {
        XCTAssertEqual(Set(AIMessageRole.allCases.map(\.rawValue)),
                       ["user", "assistant", "system"])
    }
}
