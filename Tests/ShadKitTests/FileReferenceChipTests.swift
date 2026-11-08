import XCTest
@testable import AIElementsUI

final class FileReferenceChipTests: XCTestCase {
    func testPathsAndFilenamesAreFileReferences() {
        for text in [
            "Sources/InfinittyKit/TerminalTabStrip.swift", "README.md", "Package.swift",
            "Foo.swift:120", "Foo.swift:12:3", "./scripts/run.sh", "~/notes.txt", ".gitignore.bak",
        ] {
            XCTAssertTrue(AIFileReference.isFileReference(text), text)
        }
    }

    func testOrdinaryInlineCodeIsLeftAlone() {
        for text in [
            "1.5", "v2.0.1", "--flag", "let x = 1", "foo()", "http://example.com/a.png",
            "a.b c.swift", "", ".", "x.", "pnpm", "1.2.3",
        ] {
            XCTAssertFalse(AIFileReference.isFileReference(text), text)
        }
    }

    func testLocationSuffixIsDroppedForTheIcon() {
        XCTAssertEqual(AIFileReference.withoutLocation("Foo.swift:12:3"), "Foo.swift")
        XCTAssertEqual(AIFileReference.symbol(for: "Foo.swift:9"), "swift")
        XCTAssertEqual(AIFileReference.symbol(for: "notes.md"), "doc.plaintext")
        XCTAssertEqual(AIFileReference.symbol(for: "a.bin"), "doc.text")
    }
}
