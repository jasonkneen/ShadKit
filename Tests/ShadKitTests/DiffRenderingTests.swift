import XCTest
@testable import AIElementsUI

/// Diff row folding and the word-diff edge cases the viewer relies on.
final class DiffRenderingTests: XCTestCase {

    private func unified(contextLines: Int) -> String {
        let body = (1...contextLines).map { " line \($0)" }.joined(separator: "\n")
        return "@@ -1,\(contextLines + 1) +1,\(contextLines + 1) @@\n\(body)\n-old\n+new"
    }

    func testLongContextRunsAreFoldable() {
        // The viewer collapses runs over its threshold; the parse must produce
        // them contiguously for that to be possible.
        let lines = AIDiffParser.parse(unified: unified(contextLines: 12))
        let contextRun = lines.prefix { $0.kind == .hunk || $0.kind == .context }
        XCTAssertGreaterThan(contextRun.filter { $0.kind == .context }.count, 6)
    }

    func testShortContextRunsStayWhole() {
        let lines = AIDiffParser.parse(unified: unified(contextLines: 3))
        XCTAssertEqual(lines.filter { $0.kind == .context }.count, 3)
    }

    func testAdditionsAndRemovalsAreNeverFolded() {
        let lines = AIDiffParser.parse(unified: unified(contextLines: 20))
        XCTAssertEqual(lines.filter { $0.kind == .added }.count, 1)
        XCTAssertEqual(lines.filter { $0.kind == .removed }.count, 1)
    }

    // MARK: - Word diff edge cases

    func testWholeLineRewriteFlagsEverything() {
        let changed = AIWordDiff.changedRanges(old: "alpha", new: "beta gamma")
        XCTAssertTrue(changed.contains(true))
    }

    func testPureInsertionFlagsOnlyTheInsertedTokens() {
        let changed = AIWordDiff.changedRanges(old: "a c", new: "a b c")
        let tokens = AIWordDiff.tokenize("a b c")
        XCTAssertEqual(zip(tokens, changed).filter { $0.1 }.map(\.0), ["b", " "])
    }

    func testTrailingChangeIsCaught() {
        let changed = AIWordDiff.changedRanges(old: "let x = 1", new: "let x = 2")
        let tokens = AIWordDiff.tokenize("let x = 2")
        XCTAssertEqual(zip(tokens, changed).filter { $0.1 }.map(\.0), ["2"])
    }

    func testLeadingChangeIsCaught() {
        let changed = AIWordDiff.changedRanges(old: "var x = 1", new: "let x = 1")
        let tokens = AIWordDiff.tokenize("let x = 1")
        XCTAssertEqual(zip(tokens, changed).filter { $0.1 }.map(\.0), ["let"])
    }

    func testEmptyNewLineFlagsNothing() {
        XCTAssertTrue(AIWordDiff.changedRanges(old: "something", new: "").isEmpty)
    }

    func testTokenizerSplitsOnPunctuationButKeepsIt() {
        XCTAssertEqual(
            AIWordDiff.tokenize("foo(bar)"), ["foo", "(", "bar", ")"])
    }

    func testTokenizerTreatsUnderscoresAsWordCharacters() {
        // `search_codebase` is one identifier, not three tokens.
        XCTAssertEqual(AIWordDiff.tokenize("search_codebase"), ["search_codebase"])
    }

    func testIndentationOnlyChangeIsDetected() {
        let changed = AIWordDiff.changedRanges(old: "x = 1", new: "    x = 1")
        XCTAssertTrue(changed.contains(true), "whitespace shifts are real changes")
    }

    // MARK: - Side-by-side pairing

    func testContextLinesAppearOnBothSidesIdentically() {
        let unified = "@@ -1,2 +1,2 @@\n context line"
        let lines = AIDiffParser.parse(unified: unified)
        let pairs = AIDiffView.splitPairs(from: lines)
        XCTAssertTrue(pairs.contains { $0.old?.text == "context line" && $0.new?.text == "context line" })
    }

    func testEqualCountChangeBlockPairsPositionally() {
        let unified = "-old one\n-old two\n+new one\n+new two"
        let lines = AIDiffParser.parse(unified: unified)
        let pairs = AIDiffView.splitPairs(from: lines)
        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs[0].old?.text, "old one")
        XCTAssertEqual(pairs[0].new?.text, "new one")
        XCTAssertEqual(pairs[1].old?.text, "old two")
        XCTAssertEqual(pairs[1].new?.text, "new two")
    }

    func testUnequalCountChangeBlockFillsTheShorterSideWithNil() {
        let unified = "-old one\n+new one\n+new two\n+new three"
        let lines = AIDiffParser.parse(unified: unified)
        let pairs = AIDiffView.splitPairs(from: lines)
        XCTAssertEqual(pairs.count, 3)
        XCTAssertEqual(pairs[0].old?.text, "old one")
        XCTAssertEqual(pairs[0].new?.text, "new one")
        XCTAssertNil(pairs[1].old)
        XCTAssertEqual(pairs[1].new?.text, "new two")
        XCTAssertNil(pairs[2].old)
        XCTAssertEqual(pairs[2].new?.text, "new three")
    }

    func testPureInsertionHasNoOldSide() {
        let unified = " context\n+added only"
        let lines = AIDiffParser.parse(unified: unified)
        let pairs = AIDiffView.splitPairs(from: lines)
        XCTAssertNil(pairs.last?.old)
        XCTAssertEqual(pairs.last?.new?.text, "added only")
    }
}
