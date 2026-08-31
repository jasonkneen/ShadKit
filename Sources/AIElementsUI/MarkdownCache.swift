import Foundation

/// Memoised markdown parsing for the transcript.
///
/// `AIResponse.body` re-runs for every message on every streamed token — SwiftUI
/// cannot prove a row is unchanged when it carries closures — and each run
/// re-parsed the whole document twice: once into blocks, once per block through
/// `AttributedString`'s inline markdown parser. That is O(transcript × tokens)
/// of parsing on the main thread, and it is what made a long conversation feel
/// heavy while an answer streamed.
///
/// Both parses are pure functions of their source string, so they cache cleanly.
/// `NSCache` is used for its thread safety and because it evicts under memory
/// pressure: streaming produces one entry per prefix, and those prefixes are
/// garbage the moment the next token lands.
enum AIMarkdownCache {

    /// Boxes the parsed blocks so `NSCache` (which needs a class) can hold them.
    final class BlocksBox {
        let blocks: [AIMarkdownBlock]
        init(_ blocks: [AIMarkdownBlock]) { self.blocks = blocks }
    }

    final class InlineBox {
        let attributed: AttributedString
        init(_ attributed: AttributedString) { self.attributed = attributed }
    }

    private static let blockCache: NSCache<NSString, BlocksBox> = {
        let cache = NSCache<NSString, BlocksBox>()
        // Roughly a long conversation's worth of rows plus the prefixes of one
        // in-flight answer. Entries are small; the cost of a miss is a reparse.
        cache.countLimit = 512
        return cache
    }()

    private static let inlineCache: NSCache<NSString, InlineBox> = {
        let cache = NSCache<NSString, InlineBox>()
        // Inline spans are per block, so there are several per message.
        cache.countLimit = 2048
        return cache
    }()

    static func blocks(for source: String) -> [AIMarkdownBlock] {
        blocksBox(for: source).blocks
    }

    static func blocksBox(for source: String) -> BlocksBox {
        let key = source as NSString
        if let hit = blockCache.object(forKey: key) { return hit }
        let box = BlocksBox(AIMarkdownBlock.parse(source))
        blockCache.setObject(box, forKey: key)
        return box
    }

    static func inline(_ text: String) -> AttributedString {
        inlineBox(for: text).attributed
    }

    static func inlineBox(for text: String) -> InlineBox {
        let key = text as NSString
        if let hit = inlineCache.object(forKey: key) { return hit }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        // A half-streamed span should never blank the message, so an
        // unparseable source falls back to its raw characters.
        let source = AIMarkdownBlock.balancingEmphasis(text)
        let attributed = (try? AttributedString(markdown: source, options: options))
            ?? AttributedString(source)

        let box = InlineBox(attributed)
        inlineCache.setObject(box, forKey: key)
        return box
    }

    /// Test seam: caches are process-wide, so a test that asserts on identity
    /// needs a clean slate.
    static func removeAll() {
        blockCache.removeAllObjects()
        inlineCache.removeAllObjects()
    }
}
