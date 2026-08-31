import XCTest
@testable import AIElementsUI

/// The transcript re-evaluates every message body on every streamed token, so
/// the block parse and the inline `AttributedString` parse have to be memoised
/// or the cost is O(transcript x tokens) on the main thread.
final class MarkdownCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AIMarkdownCache.removeAll()
    }

    func testBlocksMatchTheUncachedParser() {
        let source = "# Title\n\nBody **bold**\n\n- one\n- two\n\n```swift\nlet x = 1\n```"
        XCTAssertEqual(AIMarkdownCache.blocks(for: source), AIMarkdownBlock.parse(source))
    }

    func testRepeatedParseIsServedFromCache() {
        let source = "Streaming answer with some length to it."
        let first = AIMarkdownCache.blocksBox(for: source)
        let second = AIMarkdownCache.blocksBox(for: source)
        XCTAssertTrue(first === second, "A repeated parse of identical markdown must not re-parse")
    }

    func testDifferentSourcesDoNotShareAnEntry() {
        let a = AIMarkdownCache.blocksBox(for: "one")
        let b = AIMarkdownCache.blocksBox(for: "two")
        XCTAssertFalse(a === b)
        XCTAssertEqual(a.blocks, [.paragraph("one")])
        XCTAssertEqual(b.blocks, [.paragraph("two")])
    }

    func testStreamingPrefixesEachGetTheirOwnEntry() {
        // Every token produces a new string; the cache must still return the
        // right blocks for each rather than serving a stale prefix.
        let full = "Hello world"
        for end in full.indices {
            let prefix = String(full[full.startIndex...end])
            XCTAssertEqual(AIMarkdownCache.blocks(for: prefix), AIMarkdownBlock.parse(prefix))
        }
    }

    func testInlineMatchesTheUncachedParse() {
        let text = "some **bold** and `code`"
        let cached = AIMarkdownCache.inline(text)
        XCTAssertEqual(String(cached.characters), String(Self.uncachedInline(text).characters))
    }

    func testRepeatedInlineIsServedFromCache() {
        let text = "a repeated inline span"
        let first = AIMarkdownCache.inlineBox(for: text)
        let second = AIMarkdownCache.inlineBox(for: text)
        XCTAssertTrue(first === second)
    }

    func testInlineFallsBackToPlainTextOnUnparseableMarkdown() {
        // A half-streamed link should render as its raw characters, never blank.
        let text = "see [the docs"
        XCTAssertEqual(String(AIMarkdownCache.inline(text).characters), "see [the docs")
    }

    private static func uncachedInline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let source = AIMarkdownBlock.balancingEmphasis(text)
        return (try? AttributedString(markdown: source, options: options))
            ?? AttributedString(source)
    }
}
