import XCTest
@testable import AIElementsUI

/// Guards `AIQuestionForm.aggregate`, the pure fold behind the question
/// form's submitted answers.
final class QuestionFormAggregationTests: XCTestCase {

    private var questions: [AIQuestion] {
        [
            AIQuestion(id: "q1", prompt: "Which frameworks?", kind: .multiSelect(["SwiftUI", "UIKit"])),
            AIQuestion(id: "q2", prompt: "Ship it?", kind: .confirm),
            AIQuestion(id: "q3", prompt: "Anything else?", kind: .text),
            AIQuestion(id: "q4", prompt: "Which platform?", kind: .choice(["macOS", "iOS"])),
        ]
    }

    func testJoinsPicksAndWriteInWithComma() {
        let result = AIQuestionForm.aggregate(
            questions: questions,
            selections: ["q1": ["SwiftUI", "UIKit"]],
            writeIns: ["q1": "and watchOS"]
        )
        XCTAssertEqual(result["q1"], "SwiftUI, UIKit, and watchOS")
    }

    func testPreservesDeclaredOptionOrderNotSelectionOrder() {
        let result = AIQuestionForm.aggregate(
            questions: questions,
            selections: ["q1": ["UIKit", "SwiftUI"]],
            writeIns: [:]
        )
        XCTAssertEqual(result["q1"], "SwiftUI, UIKit")
    }

    func testConfirmUsesThePickedYesOrNo() {
        let result = AIQuestionForm.aggregate(
            questions: questions,
            selections: ["q2": ["Yes"]],
            writeIns: [:]
        )
        XCTAssertEqual(result["q2"], "Yes")
    }

    func testTextQuestionUsesWriteInAlone() {
        let result = AIQuestionForm.aggregate(
            questions: questions,
            selections: [:],
            writeIns: ["q3": "Nothing more."]
        )
        XCTAssertEqual(result["q3"], "Nothing more.")
    }

    func testOmitsQuestionsWithNoAnswer() {
        let result = AIQuestionForm.aggregate(
            questions: questions,
            selections: [:],
            writeIns: ["q3": "   "]
        )
        XCTAssertNil(result["q3"])
        XCTAssertNil(result["q4"])
        XCTAssertTrue(result.isEmpty)
    }

    func testChoiceAndWriteInCombine() {
        let result = AIQuestionForm.aggregate(
            questions: questions,
            selections: ["q4": ["macOS"]],
            writeIns: ["q4": "primarily"]
        )
        XCTAssertEqual(result["q4"], "macOS, primarily")
    }
}
