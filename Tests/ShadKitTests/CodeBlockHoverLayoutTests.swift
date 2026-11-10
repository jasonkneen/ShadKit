import AppKit
import SwiftUI
import XCTest

@testable import AIElementsUI
@testable import ShadcnUI

/// Hovering a code block shows its copy control. That must never change the
/// block's size: a one-line block set in small type used to grow.
@MainActor
final class CodeBlockHoverLayoutTests: XCTestCase {
    private func size(hovering: Bool, textSize: CGFloat) -> CGSize {
        var theme = ShadcnTheme()
        theme.typography.sm = ShadcnTypography.Step(size: textSize, lineHeight: textSize + 3)
        let view = AICodeBlock(code: "ls", language: "bash", hoveringForTesting: hovering)
            .environment(\.shadcnTheme, theme)
            .frame(width: 240)
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    func testHoverControlsDoNotChangeTheBlocksSize() {
        for textSize in [8, 9, 11, 13] as [CGFloat] {
            XCTAssertEqual(
                size(hovering: true, textSize: textSize), size(hovering: false, textSize: textSize),
                "text size \(textSize)")
        }
    }

    func testTheControlFitsInsideAOneLineBlockInTheSmallestType() {
        let block = size(hovering: false, textSize: 8)
        XCTAssertGreaterThanOrEqual(block.height, AICodeBlock.controlSize + 2 * Space.x1)
    }
}
