import AIElementsGallery
import AppKit
import XCTest
@testable import ShadcnUI

final class GalleryGlassTests: XCTestCase {
    func testGlassSectionIsInTheCatalog() {
        XCTAssertEqual(GallerySection.glass.rawValue, "glass")
        XCTAssertTrue(GallerySection.allCases.contains(.glass))
    }

    func testGalleryWindowInstallsBehindWindowGlass() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        ShadcnGalleryWindow.install(ShadcnAIGallery(surfaceOpacity: 0.45), in: window)
        XCTAssertFalse(window.isOpaque)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertLessThan(window.backgroundColor.alphaComponent, 0.01)
        if #available(macOS 26.0, *) {
            XCTAssertTrue(window.contentView is NSGlassEffectView)
        } else {
            let blur = window.contentView as? NSVisualEffectView
            XCTAssertEqual(blur?.blendingMode, .behindWindow)
        }
    }
}
