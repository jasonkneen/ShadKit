import XCTest
@testable import ShadcnUI

/// Pins U22: `ShadcnSelect`'s icon trigger never tints with `palette.primary`
/// unless `tintsTriggerWithPrimary` opts in.
final class SelectTriggerTintTests: XCTestCase {
    private let palette = ShadcnTheme.default.palette(for: .light)

    func testSelectedGlyphUsesForegroundByDefault() {
        let tint = shadcnSelectTriggerIconTint(
            isSelected: true, tintsWithPrimary: false, palette: palette)
        XCTAssertEqual(tint, palette.foreground)
        XCTAssertNotEqual(tint, palette.primary)
    }

    func testUnselectedGlyphUsesMutedForegroundByDefault() {
        let tint = shadcnSelectTriggerIconTint(
            isSelected: false, tintsWithPrimary: false, palette: palette)
        XCTAssertEqual(tint, palette.mutedForeground)
        XCTAssertNotEqual(tint, palette.primary)
    }

    func testOptingInTintsWithPrimaryRegardlessOfSelection() {
        XCTAssertEqual(
            shadcnSelectTriggerIconTint(isSelected: true, tintsWithPrimary: true, palette: palette),
            palette.primary)
        XCTAssertEqual(
            shadcnSelectTriggerIconTint(isSelected: false, tintsWithPrimary: true, palette: palette),
            palette.primary)
    }
}
