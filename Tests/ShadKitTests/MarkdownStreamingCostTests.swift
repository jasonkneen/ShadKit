import XCTest
@testable import AIElementsUI

/// What re-parsing a growing answer costs per streamed token.
final class MarkdownStreamingCostTests: XCTestCase {
    static let paragraph = "The hand-off path now keeps the group id, and `QueuedTaskPlanTests` passes with **all ten** tests. See [the docs](https://example.com) for more.\n\n- one item with `code`\n- two items\n\n```swift\nlet value = 42\nprint(value)\n```\n\n"

    func testCostOfReparsingAGrowingAnswer() {
        let full = String(repeating: Self.paragraph, count: 40) // ~8.6KB
        let characters = Array(full)
        AIMarkdownCache.removeAll()
        var samples: [Double] = []
        var index = characters.count - 600
        while index < characters.count {
            let prefix = String(characters[..<index])
            let begin = CFAbsoluteTimeGetCurrent()
            _ = AIMarkdownCache.blocks(for: prefix, width: nil)
            samples.append(CFAbsoluteTimeGetCurrent() - begin)
            index += 5
        }
        let sorted = samples.sorted()
        // A streamed token re-parses the whole answer; that has to stay far
        // below a frame, even unoptimised.
        XCTAssertLessThan(sorted[sorted.count / 2] * 1000, 4)
        print(String(format: "MD_STREAM full=%dB median=%.2fms p95=%.2fms",
                     full.utf8.count, sorted[sorted.count / 2] * 1000, sorted[Int(Double(sorted.count) * 0.95)] * 1000))
    }
}
