import XCTest
@testable import AIElementsUI

/// The block parser sits under every assistant message and had no direct
/// coverage. Streaming is the hard case: the document is always truncated.
final class MarkdownBlockTests: XCTestCase {

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
                [.list(items: ["a", "b"], isOrdered: false)],
                "marker \(marker)")
        }
    }

    func testOrderedList() {
        XCTAssertEqual(
            AIMarkdownBlock.parse("1. first\n2. second"),
            [.list(items: ["first", "second"], isOrdered: true)])
    }

    func testSwitchingListKindStartsANewBlock() {
        let blocks = AIMarkdownBlock.parse("- bullet\n1. number")
        XCTAssertEqual(
            blocks,
            [
                .list(items: ["bullet"], isOrdered: false),
                .list(items: ["number"], isOrdered: true),
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
                .list(items: ["a", "b"], isOrdered: false),
                .code("code", language: "swift"),
                .quote("note"),
            ])
    }

    func testProseInterruptingAListClosesIt() {
        let blocks = AIMarkdownBlock.parse("- a\nnot an item")
        XCTAssertEqual(
            blocks, [.list(items: ["a"], isOrdered: false), .paragraph("not an item")])
    }
}
