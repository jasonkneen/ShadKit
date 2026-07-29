import SwiftUI
import XCTest
@testable import ShadcnUI

#if canImport(AppKit)
import AppKit
#endif

/// Guards the token tables themselves. A transposed field here is invisible in
/// one appearance and catastrophic in the other, so both are pinned to hex.
final class PaletteTests: XCTestCase {

    func testLightSpecMatchesShadcnNeutral() {
        let light = ShadcnPaletteSpec.neutralLight
        XCTAssertEqual(light.background.hexString, "#FFFFFF")
        XCTAssertEqual(light.foreground.hexString, "#0A0A0A")
        XCTAssertEqual(light.primary.hexString, "#171717")
        XCTAssertEqual(light.primaryForeground.hexString, "#FAFAFA")
        XCTAssertEqual(light.secondary.hexString, "#F5F5F5")
        XCTAssertEqual(light.mutedForeground.hexString, "#737373")
        XCTAssertEqual(light.border.hexString, "#E5E5E5")
    }

    func testDarkSpecMatchesShadcnNeutral() {
        let dark = ShadcnPaletteSpec.neutralDark
        XCTAssertEqual(dark.background.hexString, "#0A0A0A")
        // The one that matters most: body text must be near-white in dark.
        XCTAssertEqual(dark.foreground.hexString, "#FAFAFA")
        XCTAssertEqual(dark.card.hexString, "#171717")
        XCTAssertEqual(dark.primary.hexString, "#E5E5E5")
        XCTAssertEqual(dark.primaryForeground.hexString, "#171717")
        XCTAssertEqual(dark.secondary.hexString, "#262626")
        XCTAssertEqual(dark.secondaryForeground.hexString, "#FAFAFA")
        XCTAssertEqual(dark.mutedForeground.hexString, "#A1A1A1")
    }

    func testDarkForegroundAndBackgroundAreNotSwapped() {
        let dark = ShadcnPaletteSpec.neutralDark
        XCTAssertGreaterThan(
            dark.foreground.l, dark.background.l,
            "dark mode must render light text on a dark surface"
        )
    }

    /// The resolved palette is what components actually read, so verify the
    /// `Color` values survive the spec -> palette hop.
    func testResolvedPaletteKeepsFieldsInPlace() throws {
        #if canImport(AppKit)
        let palette = ShadcnTheme.default.palette(for: .dark)
        XCTAssertTrue(palette.isDark)

        let foreground = try XCTUnwrap(NSColor(palette.foreground).usingColorSpace(.sRGB))
        // Near-white: every channel above 0.9.
        XCTAssertGreaterThan(foreground.redComponent, 0.9)
        XCTAssertGreaterThan(foreground.greenComponent, 0.9)
        XCTAssertGreaterThan(foreground.blueComponent, 0.9)

        let background = try XCTUnwrap(NSColor(palette.background).usingColorSpace(.sRGB))
        XCTAssertLessThan(background.redComponent, 0.1)
        #endif
    }

    func testLightAndDarkResolveDifferently() throws {
        #if canImport(AppKit)
        let light = try XCTUnwrap(
            NSColor(ShadcnTheme.default.palette(for: .light).foreground)
                .usingColorSpace(.sRGB)
        )
        let dark = try XCTUnwrap(
            NSColor(ShadcnTheme.default.palette(for: .dark).foreground)
                .usingColorSpace(.sRGB)
        )
        XCTAssertNotEqual(light.redComponent, dark.redComponent, accuracy: 0.0)
        XCTAssertLessThan(light.redComponent, dark.redComponent)
        #endif
    }
}
