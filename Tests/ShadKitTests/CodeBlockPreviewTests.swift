import XCTest
@testable import AIElementsUI

/// Guards `AICodeBlockPreview`, the pure rule behind `AICodeBlock`'s
/// preview/source toggle (D2: no WebKit — the host injects a renderer).
final class CodeBlockPreviewTests: XCTestCase {

    func testIsPreviewableForHTMLAndSVG() {
        XCTAssertTrue(AICodeBlockPreview.isPreviewable("html"))
        XCTAssertTrue(AICodeBlockPreview.isPreviewable("HTML"))
        XCTAssertTrue(AICodeBlockPreview.isPreviewable("svg"))
    }

    func testIsPreviewableFalseForOtherLanguages() {
        XCTAssertFalse(AICodeBlockPreview.isPreviewable("swift"))
        XCTAssertFalse(AICodeBlockPreview.isPreviewable("json"))
        XCTAssertFalse(AICodeBlockPreview.isPreviewable(nil))
    }

    func testCanPreviewRequiresRenderer() {
        XCTAssertFalse(
            AICodeBlockPreview.canPreview(hasRenderer: false, language: "html", isStreaming: false)
        )
        XCTAssertTrue(
            AICodeBlockPreview.canPreview(hasRenderer: true, language: "html", isStreaming: false)
        )
    }

    func testCanPreviewFalseWhileStreaming() {
        XCTAssertFalse(
            AICodeBlockPreview.canPreview(hasRenderer: true, language: "html", isStreaming: true)
        )
    }

    func testCanPreviewFalseForNonPreviewableLanguage() {
        XCTAssertFalse(
            AICodeBlockPreview.canPreview(hasRenderer: true, language: "swift", isStreaming: false)
        )
    }

    func testCanPreviewFalseForNilLanguage() {
        XCTAssertFalse(
            AICodeBlockPreview.canPreview(hasRenderer: true, language: nil, isStreaming: false)
        )
    }
}
