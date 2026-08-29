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
}
#endif
