import XCTest
@testable import ShadcnUI

final class SelectSearchTests: XCTestCase {
    func testFuzzyMatchingSupportsSkippedCharactersAndCase() {
        XCTAssertNotNil(ShadcnSelectSearch.score(query: "jbmn", label: "JetBrains Mono"))
        XCTAssertNotNil(ShadcnSelectSearch.score(query: "extra light", label: "ExtraLight"))
        XCTAssertNil(ShadcnSelectSearch.score(query: "xyz", label: "JetBrains Mono"))
        XCTAssertEqual(ShadcnSelectSearch.score(query: "inter", label: "Inter"), 0)
        XCTAssertLessThan(ShadcnSelectSearch.score(query: "mono", label: "Mono")!,
                          ShadcnSelectSearch.score(query: "mono", label: "JetBrains Mono")!)
    }
}
