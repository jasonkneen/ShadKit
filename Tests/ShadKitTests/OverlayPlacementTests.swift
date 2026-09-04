import SwiftUI
import XCTest
@testable import ShadcnUI

/// Pins overlay placement math so menus stop flying in from the origin and so
/// bottom-of-panel selects can open upward with a known height.
final class OverlayPlacementTests: XCTestCase {

    func testOverlayHostReceivesTheResolvedDarkPaletteExplicitly() {
        let theme = ShadcnTheme.default
        let host = ShadcnOverlayHost(
            theme: theme,
            palette: theme.palette(for: .dark),
            colorScheme: .dark,
            surfaceOpacity: 0.4)
        XCTAssertTrue(host.palette.isDark)
        XCTAssertEqual(host.colorScheme, .dark)
        XCTAssertEqual(host.surfaceOpacity, 0.4, accuracy: 0.001)
        XCTAssertTrue(host.glassEnabled)
    }

    func testTranslucentFillUsesMaterialOnlyWhenGlassIsOn() {
        XCTAssertTrue(ShadcnSurfaceFill.usesMaterial(glass: true))
        XCTAssertFalse(ShadcnSurfaceFill.usesMaterial(glass: false))
        // Glass off: opacity is a flat alpha, no frost.
        XCTAssertEqual(ShadcnSurfaceFill.tintOpacity(1, glass: false), 1, accuracy: 0.001)
        XCTAssertEqual(ShadcnSurfaceFill.tintOpacity(0.5, glass: false), 0.5, accuracy: 0.001)
        // Glass on: light wash over material, even at full pane opacity.
        XCTAssertEqual(
            ShadcnSurfaceFill.tintOpacity(1, glass: true),
            ShadcnSurfaceFill.maximumTranslucentTint,
            accuracy: 0.001)
        XCTAssertEqual(ShadcnSurfaceFill.tintOpacity(0.1, glass: true), 0.04, accuracy: 0.001)
    }

    func testBottomEdgeAnchorsJustBelowTheTrigger() {
        let trigger = CGRect(x: 40, y: 100, width: 120, height: 28)
        let origin = ShadcnOverlayPlacement.origin(
            trigger: trigger,
            edge: .bottom,
            alignment: .leading,
            gap: 4,
            contentHeight: nil
        )
        XCTAssertEqual(origin.x, 40)
        XCTAssertEqual(origin.y, 132) // 100 + 28 + 4
    }

    func testTopEdgeUsesContentHeightSoThePanelSitsFullyAbove() {
        let trigger = CGRect(x: 40, y: 400, width: 120, height: 28)
        let height: CGFloat = 120
        let origin = ShadcnOverlayPlacement.origin(
            trigger: trigger,
            edge: .top,
            alignment: .leading,
            gap: 4,
            contentHeight: height
        )
        XCTAssertEqual(origin.x, 40)
        // Top of menu = trigger.minY - gap - height
        XCTAssertEqual(origin.y, 400 - 4 - 120)
        // Menu bottom lands at trigger.minY - gap (does not cover the trigger).
        XCTAssertEqual(origin.y + height, 396)
    }

    func testTopEdgeWithoutHeightStillLeavesTheGapAboveTheTrigger() {
        // Without a height the top of the panel is at minY - gap; the panel
        // then grows downward. Callers that open upward must pass a height.
        let trigger = CGRect(x: 0, y: 200, width: 80, height: 20)
        let origin = ShadcnOverlayPlacement.origin(
            trigger: trigger,
            edge: .top,
            alignment: .leading,
            gap: 4,
            contentHeight: nil
        )
        XCTAssertEqual(origin.y, 196)
    }

    func testTrailingAlignmentPinsToTheTriggerTrailingEdge() {
        let trigger = CGRect(x: 10, y: 10, width: 100, height: 20)
        let origin = ShadcnOverlayPlacement.origin(
            trigger: trigger,
            edge: .bottom,
            alignment: .trailing,
            gap: 4,
            contentHeight: nil
        )
        XCTAssertEqual(origin.x, 110)
    }

    func testSelectPanelHeightGrowsWithRowCount() {
        let one = ShadcnSelect<String>.panelHeight(rows: 1)
        let five = ShadcnSelect<String>.panelHeight(rows: 5)
        XCTAssertGreaterThan(five, one)
        XCTAssertEqual(five - one, (one - (Space.x1 * 2 + 2)) * 4, accuracy: 0.5)
    }

    func testSelectPanelHeightCapsAtMaxVisibleRows() {
        // A 30-item list opening upward must not claim 30 rows of placement
        // height — that parks only the tail of the menu near the trigger.
        let capped = ShadcnSelect<String>.panelHeight(rows: 30, maxVisibleRows: 8)
        let eight = ShadcnSelect<String>.panelHeight(rows: 8, maxVisibleRows: 8)
        let nine = ShadcnSelect<String>.panelHeight(rows: 9, maxVisibleRows: 8)
        XCTAssertEqual(capped, eight)
        XCTAssertEqual(nine, eight)
        XCTAssertLessThan(capped, ShadcnSelect<String>.panelHeight(rows: 30, maxVisibleRows: 30))
    }

    func testTopEdgePlacementWithCappedHeightKeepsMenuNearTrigger() {
        let trigger = CGRect(x: 40, y: 500, width: 120, height: 28)
        let height = ShadcnSelect<String>.panelHeight(rows: 40, maxVisibleRows: 8)
        let origin = ShadcnOverlayPlacement.origin(
            trigger: trigger,
            edge: .top,
            alignment: .leading,
            gap: 4,
            contentHeight: height
        )
        // Bottom of the (capped) menu sits just above the trigger.
        XCTAssertEqual(origin.y + height, trigger.minY - 4, accuracy: 0.5)
        // And the top stays inside a typical ~600pt panel rather than at y≪0.
        XCTAssertGreaterThan(origin.y, 0)
    }

    func testClampKeepsAKnownWidthPanelInsideTheHost() {
        // Trailing-aligned 288pt panel whose trigger anchor ends 30pt past the
        // visible host edge (a wider-than-visible anchor, or a trigger hugging
        // the edge): the panel is pulled back so its right edge is the host's.
        let raw = ShadcnOverlayPlacement.origin(
            trigger: CGRect(x: 150, y: 10, width: 60, height: 20),
            edge: .bottom, alignment: .trailing, gap: 4,
            contentHeight: nil, contentWidth: 288)
        XCTAssertEqual(raw.x, 210 - 288)
        let clamped = ShadcnOverlayPlacement.clamped(
            raw, contentWidth: 288, contentHeight: nil, in: CGSize(width: 400, height: 300))
        XCTAssertEqual(clamped.x, 0, "never left of the host")
        let overflowing = ShadcnOverlayPlacement.clamped(
            CGPoint(x: 380, y: 34), contentWidth: 288, contentHeight: nil,
            in: CGSize(width: 400, height: 300))
        XCTAssertEqual(overflowing.x, 400 - 288, "never past the host's trailing edge")
        XCTAssertEqual(overflowing.y, 34, "unknown height is left alone")
        let unknown = ShadcnOverlayPlacement.clamped(
            CGPoint(x: 380, y: 34), contentWidth: nil, contentHeight: nil,
            in: CGSize(width: 400, height: 300))
        XCTAssertEqual(unknown.x, 380, "unknown width is left alone")
    }

    // MARK: - resolved (flip + shift, U19)

    func testResolvedFlipsToTopWhenBottomWouldOverflowTheHost() {
        // Trigger near the bottom of a 300pt-tall host; a 120pt panel opening
        // .bottom would spill 52pt past the host, but it fits fully above.
        let trigger = CGRect(x: 20, y: 260, width: 100, height: 20)
        let origin = ShadcnOverlayPlacement.resolved(
            trigger: trigger, edge: .bottom, alignment: .leading, gap: 4,
            contentWidth: 200, contentHeight: 120, in: CGSize(width: 400, height: 300))
        XCTAssertEqual(origin.y, trigger.minY - 4 - 120, "flipped above the trigger")
    }

    func testResolvedFlipsToBottomWhenTopWouldOverflowTheHost() {
        // Trigger near the top; a 120pt panel opening .top would go negative,
        // but it fits fully below.
        let trigger = CGRect(x: 20, y: 10, width: 100, height: 20)
        let origin = ShadcnOverlayPlacement.resolved(
            trigger: trigger, edge: .top, alignment: .leading, gap: 4,
            contentWidth: 200, contentHeight: 120, in: CGSize(width: 400, height: 300))
        XCTAssertEqual(origin.y, trigger.maxY + 4, "flipped below the trigger")
    }

    func testResolvedKeepsThePreferredEdgeWhenNeitherSideFits() {
        // A panel taller than the host fits nowhere; keep the preferred edge
        // and let the final clamp pull it back on-screen rather than thrash.
        let trigger = CGRect(x: 20, y: 150, width: 100, height: 20)
        let origin = ShadcnOverlayPlacement.resolved(
            trigger: trigger, edge: .bottom, alignment: .leading, gap: 4,
            contentWidth: 200, contentHeight: 400, in: CGSize(width: 400, height: 300))
        XCTAssertEqual(origin.y, 0, "clamped to the host's top rather than off-screen")
    }

    func testResolvedShiftsPastTheTrailingEdgeInsteadOfClipping() {
        // Trailing-aligned select whose trigger sits right against the
        // host's right edge, so the panel's natural trailing-pinned origin
        // (trigger.maxX - width) overshoots past the host.
        let trigger = CGRect(x: 390, y: 20, width: 40, height: 28)
        let origin = ShadcnOverlayPlacement.resolved(
            trigger: trigger, edge: .bottom, alignment: .trailing, gap: 4,
            contentWidth: 220, contentHeight: 100, in: CGSize(width: 400, height: 300))
        XCTAssertEqual(origin.x, 400 - 220, "shifted left to stay inside the host")
    }

    func testResolvedWithoutContentHeightFallsBackToClampOnly() {
        // No measured height: flip is skipped (there is nothing to compare
        // against the host with), matching the pre-U19 `origin`+`clamped`
        // behaviour custom callers still rely on.
        let trigger = CGRect(x: 20, y: 260, width: 100, height: 20)
        let origin = ShadcnOverlayPlacement.resolved(
            trigger: trigger, edge: .bottom, alignment: .leading, gap: 4,
            contentWidth: nil, contentHeight: nil, in: CGSize(width: 400, height: 300))
        XCTAssertEqual(origin.y, trigger.maxY + 4, "not flipped without a known height")
    }
}
