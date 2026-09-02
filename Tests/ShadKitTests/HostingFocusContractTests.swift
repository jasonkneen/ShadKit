import XCTest
@testable import ShadcnUI

#if canImport(AppKit)
import AppKit
import SwiftUI

/// Guards the first-responder contract that makes typing work inside AppKit
/// hosts. A previous override called `makeFirstResponder` from inside
/// `becomeFirstResponder` (re-entrant → always false → no keystrokes).
@MainActor
final class HostingFocusContractTests: XCTestCase {

    func testFocusTargetIsTheInnerHostingViewNotTheWrapper() {
        XCTAssertTrue(
            ShadcnHostingView<Text>.focusTargetIsInnerHostingView,
            "hosts must call makeFirstResponder on focusTarget, never the wrapper"
        )

        let host = ShadcnHostingView(colorScheme: .dark) { Text("composer") }
        XCTAssertTrue(host.focusTarget is NSHostingView<AnyView>)
        XCTAssertFalse(
            host.focusTarget === host,
            "focusTarget must not be the wrapper — the wrapper cannot hold keys"
        )
        XCTAssertFalse(
            host.acceptsFirstResponder,
            "wrapper must refuse first responder so AppKit routes to the inner view"
        )
    }

    func testHostDoesNotClipOverlaysAtItsBounds() {
        let host = ShadcnHostingView(colorScheme: .dark) { Text("x") }
        XCTAssertFalse(host.clipsToBounds)
        XCTAssertFalse(host.focusTarget.clipsToBounds)
    }

    func testHostLayerStaysClearSoWindowGlassShowsThrough() {
        let host = ShadcnHostingView(colorScheme: .dark) { Text("x") }
        XCTAssertFalse(host.isOpaque)
        XCTAssertEqual(host.layer?.backgroundColor?.alpha ?? 1, 0, accuracy: 0.001)
        XCTAssertEqual(
            host.focusTarget.layer?.backgroundColor?.alpha ?? 1, 0, accuracy: 0.001)
    }

    func testHostCarriesClampedSurfaceOpacityAcrossUpdates() {
        let host = ShadcnHostingView(
            colorScheme: .dark,
            paintsBackground: true,
            surfaceOpacity: 0.35
        ) { Text("x") }
        XCTAssertEqual(host.surfaceOpacityForTesting, 0.35, accuracy: 0.001)

        host.update(theme: .default, surfaceOpacity: 2) { Text("y") }
        XCTAssertEqual(host.surfaceOpacityForTesting, 1, accuracy: 0.001)
    }

    func testHostCarriesGlassAcrossUpdates() {
        let host = ShadcnHostingView(
            colorScheme: .dark,
            glass: false
        ) { Text("x") }
        XCTAssertFalse(host.glassEnabledForTesting)
        host.update(theme: .default, glass: true) { Text("y") }
        XCTAssertTrue(host.glassEnabledForTesting)
    }

    func testWindowTransparencyMarksTheBackingNonOpaque() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.isOpaque = true
        window.backgroundColor = .black
        ShadcnWindowTransparency.apply(to: window)
        XCTAssertFalse(window.isOpaque)
        XCTAssertLessThan(window.backgroundColor.alphaComponent, 0.01)
    }

    func testWindowTransparencySwitchesEffectsToBehindWindow() {
        let effect = NSVisualEffectView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        effect.blendingMode = .withinWindow
        effect.state = .inactive
        let window = NSWindow(
            contentRect: effect.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.contentView = effect
        ShadcnWindowTransparency.apply(to: window)
        XCTAssertEqual(effect.blendingMode, .behindWindow)
        XCTAssertEqual(effect.state, .active)
    }

    func testEffectViewUsesBehindWindowBlur() {
        let blur = ShadcnWindowTransparency.effectView(
            frame: NSRect(x: 0, y: 0, width: 40, height: 40),
            material: .menu,
            cornerRadius: 8)
        XCTAssertEqual(blur.blendingMode, .behindWindow)
        XCTAssertEqual(blur.material, .menu)
        XCTAssertEqual(blur.layer?.cornerRadius, 8)
    }

    func testWrapUsesLiquidGlassOnSupportedOS() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        let wrapped = ShadcnWindowTransparency.wrap(
            content,
            frame: content.frame,
            cornerRadius: 10,
            glass: true)
        if #available(macOS 26.0, *) {
            let glass = wrapped as? NSGlassEffectView
            XCTAssertNotNil(glass)
            XCTAssertEqual(glass?.cornerRadius, 10)
            XCTAssertTrue(glass?.contentView === content)
        } else {
            XCTAssertTrue(wrapped is NSVisualEffectView)
        }
    }
}
#endif
