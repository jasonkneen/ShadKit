import XCTest
@testable import AIElementsUI

/// Guards `AIActivitySummary.summarize`, the pure roll-up behind
/// `AIActivityPanel`'s summary line.
final class ActivitySummaryTests: XCTestCase {

    func testSingularToolCall() {
        let events = [AIActivityEvent(toolName: "read_file", duration: 0.2)]
        XCTAssertEqual(
            AIActivitySummary.summarize(events: events, changes: []),
            ["1 tool call"]
        )
    }

    func testPluralToolCalls() {
        let events = [
            AIActivityEvent(toolName: "read_file", duration: 0.2),
            AIActivityEvent(toolName: "write_file", duration: 0.4),
        ]
        XCTAssertEqual(
            AIActivitySummary.summarize(events: events, changes: []),
            ["2 tool calls"]
        )
    }

    func testSubagentsCountedByDistinctName() {
        let events = [
            AIActivityEvent(toolName: "run", duration: 0.1, subagent: "researcher"),
            AIActivityEvent(toolName: "run", duration: 0.1, subagent: "researcher"),
            AIActivityEvent(toolName: "run", duration: 0.1, subagent: "planner"),
        ]
        XCTAssertEqual(
            AIActivitySummary.summarize(events: events, changes: []),
            ["3 tool calls", "2 subagents"]
        )
    }

    func testSingularSubagent() {
        let events = [AIActivityEvent(toolName: "run", duration: 0.1, subagent: "researcher")]
        XCTAssertEqual(
            AIActivitySummary.summarize(events: events, changes: []),
            ["1 tool call", "1 subagent"]
        )
    }

    func testSingularAndPluralChanges() {
        let oneChange = [AIActivityFileChange(path: "Foo.swift", additions: 3, deletions: 1)]
        XCTAssertEqual(
            AIActivitySummary.summarize(events: [], changes: oneChange),
            ["1 change"]
        )

        let twoChanges = oneChange + [AIActivityFileChange(path: "Bar.swift")]
        XCTAssertEqual(
            AIActivitySummary.summarize(events: [], changes: twoChanges),
            ["2 changes"]
        )
    }

    func testEmptyEventsAndChangesProducesNoLines() {
        XCTAssertTrue(AIActivitySummary.summarize(events: [], changes: []).isEmpty)
    }
}
