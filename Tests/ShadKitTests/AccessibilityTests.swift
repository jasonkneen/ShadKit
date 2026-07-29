import SwiftUI
import XCTest
@testable import AIElementsUI
@testable import ShadcnUI

/// Reduce-motion and labelling. Both are invisible in a screenshot, which is
/// exactly why they rot.
final class AccessibilityTests: XCTestCase {

    func testEveryToolStateLabelIsHumanReadable() {
        // These are read aloud; "output-available" would be wrong.
        XCTAssertEqual(AIToolState.outputAvailable.label, "Completed")
        XCTAssertEqual(AIToolState.inputStreaming.label, "Pending")
        XCTAssertEqual(AIToolState.approvalRequested.label, "Awaiting Approval")
        for state in AIToolState.allCases {
            XCTAssertFalse(
                state.label.contains("-"),
                "\(state) label leaks the wire format")
            XCTAssertEqual(
                state.label.first, state.label.first?.uppercased().first,
                "\(state) label should read as a sentence")
        }
    }

    func testIconNamesAreRealSFSymbolShapes() {
        // A typo yields an invisible glyph rather than an error, so check the
        // ones the AI components depend on resolve to something.
        let icons = [
            ShadcnIcon.chevronDown, ShadcnIcon.check, ShadcnIcon.checkCircle,
            ShadcnIcon.xCircle, ShadcnIcon.clock, ShadcnIcon.circle,
            ShadcnIcon.wrench, ShadcnIcon.brain, ShadcnIcon.search,
            ShadcnIcon.copy, ShadcnIcon.book, ShadcnIcon.paperclip,
            ShadcnIcon.sparkles, ShadcnIcon.globe, ShadcnIcon.refresh,
        ]
        for name in icons {
            XCTAssertFalse(name.isEmpty)
            XCTAssertFalse(name.contains(" "), "\(name) is not a symbol name")
            #if canImport(AppKit)
            XCTAssertNotNil(
                NSImage(systemSymbolName: name, accessibilityDescription: nil),
                "\(name) does not resolve to an SF Symbol")
            #endif
        }
    }

    func testEveryToolStateGlyphResolves() {
        #if canImport(AppKit)
        for state in AIToolState.allCases {
            XCTAssertNotNil(
                NSImage(systemSymbolName: state.systemImage, accessibilityDescription: nil),
                "\(state) glyph \(state.systemImage) is missing")
        }
        #endif
    }

    func testComposerSubmitGlyphResolves() {
        #if canImport(AppKit)
        XCTAssertNotNil(
            NSImage(systemSymbolName: AIPromptIcon.submit, accessibilityDescription: nil))
        #endif
    }

    func testStatusColoursMeetAMinimumContrastOnBothSurfaces() {
        // Tinted status icons sit on `secondary` in either appearance; they must
        // not vanish into it.
        let swatches = [
            AITailwindColor.yellow600, AITailwindColor.blue600,
            AITailwindColor.green600, AITailwindColor.red600, AITailwindColor.orange600,
        ]
        #if canImport(AppKit)
        for spec in [ShadcnPaletteSpec.neutralLight, .neutralDark] {
            let backdrop = NSColor(spec.secondary.color).usingColorSpace(.sRGB)!
            let backdropLuma = 0.2126 * backdrop.redComponent
                + 0.7152 * backdrop.greenComponent + 0.0722 * backdrop.blueComponent
            for swatch in swatches {
                let colour = NSColor(swatch).usingColorSpace(.sRGB)!
                let luma = 0.2126 * colour.redComponent
                    + 0.7152 * colour.greenComponent + 0.0722 * colour.blueComponent
                XCTAssertGreaterThan(
                    abs(luma - backdropLuma), 0.05,
                    "a status colour is nearly invisible on secondary")
            }
        }
        #endif
    }

    func testCompactTypeStaysLegible() {
        // Shrinking for a sidebar must not go below a readable size.
        let compact = ShadcnTypography.compact()
        XCTAssertGreaterThanOrEqual(compact.xs.size, 10)
        XCTAssertGreaterThanOrEqual(compact.sm.size, 11)
    }
}
