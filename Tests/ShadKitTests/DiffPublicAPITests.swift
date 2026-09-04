import XCTest
import AIElementsUI

/// Guards the public side-by-side pairing surface (U18): a consumer test
/// target that only has a plain `import AIElementsUI` — no `@testable` —
/// must still be able to assert on `AIDiffView`'s row pairing, matching
/// `.sideBySide`'s own rendering exactly.
final class DiffPublicAPITests: XCTestCase {
    func testSideBySidePairsIsPubliclyReachableWithoutTestableImport() {
        let unified = "-old one\n-old two\n+new one\n+new two"
        let lines = AIDiffParser.parse(unified: unified)
        let pairs = AIDiffView.sideBySidePairs(from: lines)

        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs[0].old?.text, "old one")
        XCTAssertEqual(pairs[0].new?.text, "new one")
        XCTAssertEqual(pairs[1].old?.text, "old two")
        XCTAssertEqual(pairs[1].new?.text, "new two")
    }

    func testSideBySidePairsFillsTheShortSideWithNilFromPublicAPI() {
        let unified = "-old one\n+new one\n+new two\n+new three"
        let lines = AIDiffParser.parse(unified: unified)
        let pairs = AIDiffView.sideBySidePairs(from: lines)

        XCTAssertEqual(pairs.count, 3)
        XCTAssertNil(pairs[1].old)
        XCTAssertEqual(pairs[1].new?.text, "new two")
    }
}
