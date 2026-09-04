#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import ShadcnUI

/// Hosts a real `ShadcnSelect` in a real `NSWindow`/`NSHostingView` — the
/// exact embedding (`ShadcnHostingView` inside a larger AppKit layout) the
/// in-tree SwiftUI overlay couldn't escape, and the shape team-lead asked
/// this be pinned against directly rather than only through the pure
/// `screenOrigin` math above.
final class FloatingPanelLiveWindowTests: XCTestCase {
    private var window: NSWindow?
    private var controller: ShadcnFloatingPanelController?

    @MainActor
    override func tearDown() {
        controller?.close()
        controller = nil
        window?.orderOut(nil)
        window = nil
        super.tearDown()
    }

    @MainActor
    func testSelectOpeningUpwardFromABottomRightTriggerLandsAboveItAndOnScreen() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No screen available in this environment.")
        }

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        self.window = window

        // A 200×80 anchor pinned to the bottom-right of the window —
        // narrower than the select's menu, the same shape as a composer
        // footer control that used to get clipped or (post-U19,
        // pre-this-fix) render as a 1pt sliver. Driving
        // `ShadcnFloatingPanelController` directly, rather than through
        // `ShadcnSelect`'s `.onAppear`, keeps this test independent of
        // SwiftUI's view-lifecycle timing under plain XCTest (no app run
        // loop) while still exercising the exact AppKit code this file
        // exists to pin: real `NSHostingView` content, real `fittingSize`
        // measurement, a real child `NSPanel`.
        let anchor = NSView(frame: NSRect(x: 600, y: 20, width: 200, height: 80))
        window.contentView?.addSubview(anchor)
        window.orderFront(nil)

        let controller = ShadcnFloatingPanelController()
        self.controller = controller
        controller.anchorView = anchor
        controller.show(
            edge: .top, alignment: .leading, contentWidth: 180, makesKey: false,
            onDismiss: {}
        ) {
            ShadcnPanel {
                ForEach((1...8), id: \.self) { i in
                    Text("Model \(i)").frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: 180)
            .fixedSize()
            .shadcnTheme(.default)
        }

        guard let panel = window.childWindows?.first else {
            XCTFail("ShadcnFloatingPanelController did not open a floating panel")
            return
        }

        let triggerScreenRect = anchor.convert(anchor.bounds, to: nil)
            .offsetBy(dx: window.frame.minX, dy: window.frame.minY)

        // `edge: .top`: the panel's bottom edge must sit at/above the
        // trigger's top edge (AppKit y-up — this is the exact assertion
        // that would have failed pre-fix, when the panel was a 1pt sliver
        // pinned at the trigger's own position).
        XCTAssertGreaterThanOrEqual(panel.frame.minY, triggerScreenRect.maxY - 1)
        XCTAssertGreaterThan(panel.frame.height, 20, "panel should not be the 1pt sliver this file exists to prevent")

        // And it must stay on screen — not just "above the trigger" but
        // inside the visible frame, per the flip/shift contract.
        XCTAssertTrue(
            screen.visibleFrame.insetBy(dx: -1, dy: -1).contains(panel.frame),
            "panel \(panel.frame) escaped the screen \(screen.visibleFrame)")
    }
}
#endif
