#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import AIElementsUI
@testable import ShadcnUI

@MainActor
final class ConversationMenuAppearanceTests: XCTestCase {
    func testHistoryRemainsOpaqueWithoutGlassFromATransparentPane() throws {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 500, height: 500),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.backgroundColor = .systemRed
        let button = AIConversationMenuButton(frame: NSRect(x: 10, y: 440, width: 28, height: 28))
        window.contentView?.addSubview(button)
        window.orderFront(nil)
        let coordinator = AIConversationMenu.Coordinator()
        coordinator.parent = AIConversationMenu(threads: [], activeId: nil, compact: false,
            onSelect: { _ in }, onNew: {}, onArchive: nil, onFork: nil)
        coordinator.glassEnabled = false
        coordinator.surfaceOpacity = 0
        coordinator.toggle(button)
        defer { coordinator.panelController.close() }
        let panel = try XCTUnwrap(window.childWindows?.first)
        let content = try XCTUnwrap(panel.contentView)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        let pixel = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        let expected = try XCTUnwrap(NSColor(coordinator.palette.popover).usingColorSpace(.sRGB))
        XCTAssertGreaterThan(pixel.alphaComponent, 0.95)
        XCTAssertEqual(pixel.redComponent, expected.redComponent, accuracy: 0.05)
        XCTAssertEqual(pixel.greenComponent, expected.greenComponent, accuracy: 0.05)
        XCTAssertEqual(pixel.blueComponent, expected.blueComponent, accuracy: 0.05)
    }
}
#endif
