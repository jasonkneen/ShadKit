import XCTest
@testable import AIElementsUI

/// The block parser sits under every assistant message and had no direct
/// coverage. Streaming is the hard case: the document is always truncated.
final class MarkdownBlockTests: XCTestCase {

    /// Builds a flat, depth-0 `.list` block for tests that don't care about
    /// nesting.
    private func flatList(_ texts: [String], isOrdered: Bool) -> AIMarkdownBlock {
        .list(texts.map { AIMarkdownListItem(text: $0, depth: 0, isOrdered: isOrdered) })
    }

    func testHeadingsByLevel() {
        let blocks = AIMarkdownBlock.parse("# One\n\n### Three")
        XCTAssertEqual(blocks, [.heading(level: 1, text: "One"), .heading(level: 3, text: "Three")])
    }

    func testHashWithoutSpaceIsNotAHeading() {
        // `#hashtag` and `#!/bin/sh` are prose, not headings.
        XCTAssertEqual(AIMarkdownBlock.parse("#hashtag"), [.paragraph("#hashtag")])
    }

    func testSevenHashesIsNotAHeading() {
        let blocks = AIMarkdownBlock.parse("####### too deep")
        XCTAssertEqual(blocks, [.paragraph("####### too deep")])
    }

    func testParagraphLinesJoin() {
        XCTAssertEqual(
            AIMarkdownBlock.parse("one\ntwo\n\nthree"),
            [.paragraph("one two"), .paragraph("three")])
    }

    func testUnorderedListAcceptsEveryMarker() {
        for marker in ["-", "*", "+"] {
            XCTAssertEqual(
                AIMarkdownBlock.parse("\(marker) a\n\(marker) b"),
                [flatList(["a", "b"], isOrdered: false)],
                "marker \(marker)")
        }
    }

    func testOrderedList() {
        XCTAssertEqual(
            AIMarkdownBlock.parse("1. first\n2. second"),
            [flatList(["first", "second"], isOrdered: true)])
    }

    func testSwitchingListKindStartsANewBlock() {
        let blocks = AIMarkdownBlock.parse("- bullet\n1. number")
        XCTAssertEqual(
            blocks,
            [
                flatList(["bullet"], isOrdered: false),
                flatList(["number"], isOrdered: true),
            ])
    }

    func testFencedCodeKeepsItsLanguageAndBlankLines() {
        let blocks = AIMarkdownBlock.parse("```swift\nlet a = 1\n\nlet b = 2\n```")
        XCTAssertEqual(blocks, [.code("let a = 1\n\nlet b = 2", language: "swift")])
    }

    func testUnterminatedFenceStillYieldsCode() {
        // The constant case while streaming: the closing fence hasn't arrived.
        let blocks = AIMarkdownBlock.parse("```swift\nlet a = 1")
        XCTAssertEqual(blocks, [.code("let a = 1", language: "swift")])
    }

    func testFenceWithoutLanguage() {
        XCTAssertEqual(AIMarkdownBlock.parse("```\nplain\n```"), [.code("plain", language: nil)])
    }

    func testMarkersInsideCodeAreNotParsed() {
        // A `#` or `-` inside a fence is code, not a heading or a list.
        let blocks = AIMarkdownBlock.parse("```sh\n# comment\n- not a list\n```")
        XCTAssertEqual(blocks, [.code("# comment\n- not a list", language: "sh")])
    }

    func testBlockquoteLinesJoin() {
        XCTAssertEqual(AIMarkdownBlock.parse("> one\n> two"), [.quote("one two")])
    }

    func testHorizontalRules() {
        for rule in ["---", "***", "___"] {
            XCTAssertEqual(AIMarkdownBlock.parse(rule), [.rule], "rule \(rule)")
        }
    }

    func testEmptyInputYieldsNothing() {
        XCTAssertTrue(AIMarkdownBlock.parse("").isEmpty)
        XCTAssertTrue(AIMarkdownBlock.parse("\n\n").isEmpty)
    }

    func testMixedDocumentKeepsOrder() {
        let blocks = AIMarkdownBlock.parse(
            "# Title\n\nintro\n\n- a\n- b\n\n```swift\ncode\n```\n\n> note")
        XCTAssertEqual(
            blocks,
            [
                .heading(level: 1, text: "Title"),
                .paragraph("intro"),
                flatList(["a", "b"], isOrdered: false),
                .code("code", language: "swift"),
                .quote("note"),
            ])
    }

    func testProseInterruptingAListClosesIt() {
        let blocks = AIMarkdownBlock.parse("- a\nnot an item")
        XCTAssertEqual(
            blocks, [flatList(["a"], isOrdered: false), .paragraph("not an item")])
    }

    // MARK: - Nested lists

    func testNestedItemsRecordIncreasingDepth() {
        let blocks = AIMarkdownBlock.parse("- top\n  - nested\n    - deeper")
        guard case let .list(items)? = blocks.first else {
            return XCTFail("expected a single list block")
        }
        XCTAssertEqual(items.map(\.depth), [0, 1, 2])
        XCTAssertEqual(items.map(\.text), ["top", "nested", "deeper"])
    }

    func testNestedItemOfADifferentKindStaysInTheSameBlockAsItsParent() {
        let blocks = AIMarkdownBlock.parse("1. top\n   - nested bullet")
        XCTAssertEqual(blocks.count, 1, "a nested item must not start a new block")
        guard case let .list(items)? = blocks.first else {
            return XCTFail("expected a single list block")
        }
        XCTAssertEqual(items.map(\.isOrdered), [true, false])
    }

    func testTwoTopLevelListsOfDifferentKindsStayTwoBlocks() {
        let blocks = AIMarkdownBlock.parse("- bullet\n1. number")
        XCTAssertEqual(blocks.count, 2)
    }

    // MARK: - Tables

    func testTableWithAlignmentsAndRows() {
        let blocks = AIMarkdownBlock.parse(
            "| Left | Center | Right |\n|:---|:---:|---:|\n| a | b | c |")
        XCTAssertEqual(
            blocks,
            [
                .table(
                    headers: ["Left", "Center", "Right"],
                    alignments: [.leading, .center, .trailing],
                    rows: [["a", "b", "c"]]),
            ])
    }

    func testTableWithoutExplicitAlignmentDefaultsToLeading() {
        let blocks = AIMarkdownBlock.parse("| A | B |\n|---|---|\n| 1 | 2 |")
        XCTAssertEqual(
            blocks,
            [.table(headers: ["A", "B"], alignments: [.leading, .leading], rows: [["1", "2"]])])
    }

    func testMismatchedHeaderAndDelimiterColumnCountsIsNotATable() {
        let blocks = AIMarkdownBlock.parse("| A | B |\n|---|\n| 1 | 2 |")
        XCTAssertTrue(blocks.allSatisfy {
            if case .table = $0 { return false }
            return true
        })
    }

    func testHeaderWithoutADelimiterRowIsNotATable() {
        let blocks = AIMarkdownBlock.parse("| Name | Age |\nAlice")
        XCTAssertTrue(blocks.allSatisfy {
            if case .table = $0 { return false }
            return true
        })
    }
}
