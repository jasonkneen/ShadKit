#if canImport(AppKit)
import AppKit
import XCTest
@testable import ShadcnUI

/// Pins `ShadcnFloatingPanelController.screenOrigin` — the AppKit y-up
/// screen-space adapter around `ShadcnOverlayPlacement.resolved` — since a
/// sign error here reproduces exactly the U19 regression (a purely in-tree
/// SwiftUI overlay can't escape a pane smaller than the panel; this bridge
/// exists to sidestep that, but only if the math is right).
final class FloatingPanelScreenOriginTests: XCTestCase {
    /// A 1200×800 screen with its origin not at (0, 0), the way a secondary
    /// monitor (or a primary display below the menu bar) actually reports.
    private let screen = CGRect(x: 100, y: 50, width: 1200, height: 800)

    func testBottomEdgeOpensBelowTheTriggerInScreenSpace() {
        // A trigger near the screen's top: opening `.bottom` has plenty of
        // room below it (smaller AppKit y = further down the screen).
        let trigger = CGRect(x: 200, y: 700, width: 40, height: 24)
        let origin = ShadcnFloatingPanelController.screenOrigin(
            anchor: trigger, edge: .bottom, alignment: .leading, gap: 4,
            width: 180, height: 120, screen: screen)
        // Panel's top must sit `gap` below the trigger's bottom edge.
        XCTAssertEqual(origin.y + 120, trigger.minY - 4, accuracy: 0.5)
        XCTAssertEqual(origin.x, trigger.minX, accuracy: 0.5)
    }

    func testTopEdgeOpensAboveTheTriggerInScreenSpace() {
        let trigger = CGRect(x: 200, y: 100, width: 40, height: 24)
        let origin = ShadcnFloatingPanelController.screenOrigin(
            anchor: trigger, edge: .top, alignment: .leading, gap: 4,
            width: 180, height: 120, screen: screen)
        // Panel's bottom must sit `gap` above the trigger's top edge.
        XCTAssertEqual(origin.y, trigger.maxY + 4, accuracy: 0.5)
    }

    func testFlipsToTopWhenBottomWouldRunOffTheBottomOfTheScreen() {
        // Trigger near the screen's bottom edge (AppKit y close to
        // screen.minY): `.bottom` has no room, but `.top` does.
        let trigger = CGRect(x: 200, y: screen.minY + 20, width: 40, height: 24)
        let origin = ShadcnFloatingPanelController.screenOrigin(
            anchor: trigger, edge: .bottom, alignment: .leading, gap: 4,
            width: 180, height: 120, screen: screen)
        // Flipped: panel's bottom sits above the trigger's top edge.
        XCTAssertEqual(origin.y, trigger.maxY + 4, accuracy: 0.5)
    }

    func testFlipsToBottomWhenTopWouldRunOffTheTopOfTheScreen() {
        let trigger = CGRect(x: 200, y: screen.maxY - 40, width: 40, height: 24)
        let origin = ShadcnFloatingPanelController.screenOrigin(
            anchor: trigger, edge: .top, alignment: .leading, gap: 4,
            width: 180, height: 120, screen: screen)
        XCTAssertEqual(origin.y + 120, trigger.minY - 4, accuracy: 0.5)
    }

    func testTrailingAlignmentStaysInsideTheScreensRightEdge() {
        // Trigger hugging the screen's right edge, wide panel: the trailing-
        // pinned origin would overshoot past the screen without the shift.
        let trigger = CGRect(x: screen.maxX - 40, y: 400, width: 40, height: 24)
        let origin = ShadcnFloatingPanelController.screenOrigin(
            anchor: trigger, edge: .bottom, alignment: .trailing, gap: 4,
            width: 300, height: 120, screen: screen)
        XCTAssertLessThanOrEqual(origin.x + 300, screen.maxX + 0.5)
        XCTAssertGreaterThanOrEqual(origin.x, screen.minX - 0.5)
    }

    func testOffScreenOriginScreenStillPlacesWithinBounds() {
        // A non-zero screen origin (secondary monitor) must not leak into the
        // result unconverted.
        let trigger = CGRect(x: screen.minX + 10, y: screen.minY + 10, width: 40, height: 24)
        let origin = ShadcnFloatingPanelController.screenOrigin(
            anchor: trigger, edge: .bottom, alignment: .leading, gap: 4,
            width: 180, height: 120, screen: screen)
        XCTAssertGreaterThanOrEqual(origin.x, screen.minX - 0.5)
        XCTAssertGreaterThanOrEqual(origin.y, screen.minY - 0.5)
    }
}
#endif
