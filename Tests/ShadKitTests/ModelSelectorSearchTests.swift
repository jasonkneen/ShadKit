import XCTest
@testable import AIElementsUI

final class ModelSelectorSearchTests: XCTestCase {
    private let models = [
        AIModelOption(id: "openai/gpt-5.6-sol", name: "GPT-5.6 Sol", provider: "OpenAI"),
        AIModelOption(id: "qwen/qwen3.8-max", name: "Qwen 3.8 Max", provider: "Alibaba"),
        AIModelOption(id: "anthropic/claude-opus-5", name: "Claude Opus 5", provider: "Anthropic"),
    ]

    func testExactNameMatchRanksFirst() {
        let competing = [
            AIModelOption(id: "fuzzy", name: "Rapid Orion", provider: "A"),
            AIModelOption(id: "exact", name: "Pro", provider: "Z"),
        ]
        let results = AIModelSelectorSearch.ranked(competing, query: "pro")
        XCTAssertEqual(results.map(\.id), ["exact", "fuzzy"])
        let sections = AIModelSelectorSearch.sections(competing, query: "pro")
        XCTAssertEqual(sections.map(\.provider), ["Z", "A"])
        XCTAssertEqual(sections.flatMap(\.models).map(\.id), ["exact", "fuzzy"])
    }

    func testCompactPunctuationFreeQueryMatchesModelName() {
        let results = AIModelSelectorSearch.ranked(models, query: "gpt56")
        XCTAssertEqual(results.first?.id, "openai/gpt-5.6-sol")
    }

    func testAbbreviatedQueryMatchesAsAnOrderedSubsequence() {
        let results = AIModelSelectorSearch.ranked(models, query: "qwn max")
        XCTAssertEqual(results.first?.id, "qwen/qwen3.8-max")
    }

    func testProviderAndIdentifierAreSearchable() {
        XCTAssertEqual(
            AIModelSelectorSearch.ranked(models, query: "alibaba").first?.id,
            "qwen/qwen3.8-max")
        XCTAssertEqual(
            AIModelSelectorSearch.ranked(models, query: "openai/").first?.id,
            "openai/gpt-5.6-sol")
    }

    func testEmptyQueryPreservesCallerOrder() {
        XCTAssertEqual(AIModelSelectorSearch.ranked(models, query: "").map(\.id), models.map(\.id))
        XCTAssertEqual(AIModelSelectorSearch.sections(models, query: " \n").map(\.provider),
                       ["Alibaba", "Anthropic", "OpenAI"])
    }

    func testRecentRowRetainsDistinctRowIdentityAndCanonicalSelection() {
        let canonical = models[0]
        let recent = AIModelOption(id: "recent:\(canonical.id)", name: canonical.name,
                                   provider: "Recent", selectionID: canonical.id)
        XCTAssertNotEqual(recent.id, canonical.id)
        XCTAssertEqual(recent.selectionID, canonical.selectionID)
    }
}
