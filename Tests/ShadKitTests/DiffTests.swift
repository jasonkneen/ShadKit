import XCTest
@testable import AIElementsUI

final class DiffTests: XCTestCase {

    private let sample = """
    @@ -1,4 +1,4 @@
     let a = 1
    -let b = 2
    +let b = 22
     let c = 3
    """

    func testParserTracksBothLineNumbers() {
        let lines = AIDiffParser.parse(unified: sample)
        let context = lines.filter { $0.kind == .context }
        XCTAssertEqual(context.first?.oldNumber, 1)
        XCTAssertEqual(context.first?.newNumber, 1)
        // After a -1/+1 swap the two sides stay in step.
        XCTAssertEqual(context.last?.oldNumber, 3)
        XCTAssertEqual(context.last?.newNumber, 3)
    }

    func testRemovedLineHasNoNewNumber() throws {
        let lines = AIDiffParser.parse(unified: sample)
        let removed = try XCTUnwrap(lines.first { $0.kind == .removed })
        XCTAssertNil(removed.newNumber)
        XCTAssertEqual(removed.oldNumber, 2)
    }

    func testHunkHeaderResetsCounters() {
        let lines = AIDiffParser.parse(unified: "@@ -10,2 +20,2 @@\n a\n")
        let context = lines.first { $0.kind == .context }
        XCTAssertEqual(context?.oldNumber, 10)
        XCTAssertEqual(context?.newNumber, 20)
    }

    func testFileHeadersAreDropped() {
        let lines = AIDiffParser.parse(
            unified: "diff --git a/x b/x\nindex 1..2\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n a")
        XCTAssertFalse(lines.contains { $0.text.hasPrefix("diff ") })
        XCTAssertEqual(lines.filter { $0.kind == .context }.count, 1)
    }

    func testMarkerIsStrippedFromContent() {
        let lines = AIParserFixture.added(from: sample)
        XCTAssertEqual(lines?.text, "let b = 22", "the +/- marker is chrome, not content")
    }

    // MARK: - Word diff

    func testWordDiffFlagsOnlyTheChangedToken() {
        let changed = AIWordDiff.changedRanges(old: "let b = 2", new: "let b = 22")
        let tokens = AIWordDiff.tokenize("let b = 22")
        let flagged = zip(tokens, changed).filter { $0.1 }.map(\.0)
        // Only the number differs; the identifier and operator are untouched.
        XCTAssertEqual(flagged, ["22"])
    }

    func testTokenizerRoundTrips() {
        let line = "  let x = foo(bar, 1)"
        XCTAssertEqual(AIWordDiff.tokenize(line).joined(), line)
    }

    func testIdenticalLinesFlagNothing() {
        let changed = AIWordDiff.changedRanges(old: "same", new: "same")
        XCTAssertFalse(changed.contains(true))
    }

    func testEmptyOldMarksEverythingChanged() {
        let changed = AIWordDiff.changedRanges(old: "", new: "brand new")
        XCTAssertTrue(changed.allSatisfy { $0 })
    }
}

enum AIParserFixture {
    static func added(from unified: String) -> AIDiffLine? {
        AIDiffParser.parse(unified: unified).first { $0.kind == .added }
    }
}

/// Split mode shares the parser and word diff with unified; what differs is
/// that both gutters are shown, so these pin the data both sides need.
final class SplitDiffTests: XCTestCase {

    private let paired = """
    @@ -1,3 +1,3 @@
     keep
    -old line
    +new line
     tail
    """

    func testBothSidesCarryTheirOwnNumbers() throws {
        let lines = AIDiffParser.parse(unified: paired)
        let removed = try XCTUnwrap(lines.first { $0.kind == .removed })
        let added = try XCTUnwrap(lines.first { $0.kind == .added })

        // Split renders these on opposite sides, each with one number only.
        XCTAssertEqual(removed.oldNumber, 2)
        XCTAssertNil(removed.newNumber)
        XCTAssertEqual(added.newNumber, 2)
        XCTAssertNil(added.oldNumber)
    }

    func testContextKeepsBothSidesInStep() {
        let context = AIDiffParser.parse(unified: paired).filter { $0.kind == .context }
        XCTAssertEqual(context.map(\.oldNumber), [1, 3])
        XCTAssertEqual(context.map(\.newNumber), [1, 3])
    }

    func testUnevenHunkDoesNotDesyncTheGutters() {
        // Two removals, one addition — the sides must not drift.
        let lines = AIDiffParser.parse(
            unified: "@@ -1,4 +1,3 @@\n a\n-b\n-c\n+d\n e")
        let tail = lines.last { $0.kind == .context }
        XCTAssertEqual(tail?.oldNumber, 4)
        XCTAssertEqual(tail?.newNumber, 3)
    }

    func testWordDiffPairsAddedLineWithItsRemoval() {
        let changed = AIWordDiff.changedRanges(old: "old line", new: "new line")
        let tokens = AIWordDiff.tokenize("new line")
        let flagged = zip(tokens, changed).filter { $0.1 }.map(\.0)
        XCTAssertEqual(flagged, ["new"], "only the differing word is highlighted")
    }
}

/// Streaming markdown is routinely unbalanced — the closing marker has not
/// arrived yet — and agents emit stray runs between thoughts.
final class MarkdownBalancingTests: XCTestCase {

    func testStrayRunBetweenThoughtsDoesNotBoldTheRest() {
        // Observed from hermes: two thoughts concatenated with no separator.
        let balanced = AIMarkdownBlock.balancingEmphasis(
            "Clarifying approach****Planning with Python")
        // Whatever it becomes, it must not leave an unmatched opener.
        XCTAssertEqual(balanced.components(separatedBy: "**").count - 1, 0)
    }

    func testUnclosedEmphasisMidStreamIsDropped() {
        let balanced = AIMarkdownBlock.balancingEmphasis("the **important thing")
        XCTAssertFalse(balanced.contains("**"))
        XCTAssertTrue(balanced.contains("important thing"))
    }

    func testBalancedEmphasisIsUntouched() {
        let input = "the **important** thing"
        XCTAssertEqual(AIMarkdownBlock.balancingEmphasis(input), input)
    }

    func testTwoBalancedPairsSurvive() {
        let input = "**a** and **b**"
        XCTAssertEqual(AIMarkdownBlock.balancingEmphasis(input), input)
    }

    func testSingleAsterisksAreLeftAlone() {
        let input = "2 * 3 * 4"
        XCTAssertEqual(AIMarkdownBlock.balancingEmphasis(input), input)
    }
}
