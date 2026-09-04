import SwiftUI
import XCTest
@testable import AIElementsUI
@testable import ShadcnUI

/// Pins U21: a completed `AITodoRow`'s title colour must never be
/// `mutedForeground` — on a low-chroma terminal-derived palette that pairing
/// went grey-on-grey inside `AIPlan`'s `card` body.
final class TodoRowContrastTests: XCTestCase {

    /// Mirrors the consumer palette described in the U21 report: background
    /// and foreground come from the theme, `muted`/`mutedForeground` are the
    /// background mixed 10%/62% toward foreground.
    private static let lowChromaPalette: ShadcnPalette = ShadcnPaletteSpec(cssVars: [
        "background": "oklch(0.22 0.01 260)",
        "foreground": "oklch(0.85 0.01 260)",
        "card": "oklch(0.25 0.01 260)",
        "card-foreground": "oklch(0.85 0.01 260)",
        "popover": "oklch(0.25 0.01 260)",
        "popover-foreground": "oklch(0.85 0.01 260)",
        "primary": "oklch(0.85 0.01 260)",
        "primary-foreground": "oklch(0.22 0.01 260)",
        "secondary": "oklch(0.283 0.01 260)",
        "secondary-foreground": "oklch(0.85 0.01 260)",
        "muted": "oklch(0.283 0.01 260)",
        "muted-foreground": "oklch(0.611 0.01 260)",
        "accent": "oklch(0.283 0.01 260)",
        "accent-foreground": "oklch(0.85 0.01 260)",
        "destructive": "oklch(0.704 0.191 22.216)",
        "border": "oklch(1 0 0 / 10%)",
        "input": "oklch(1 0 0 / 15%)",
        "ring": "oklch(0.556 0.01 260)",
        "chart-1": "oklch(0.7 0.01 260)",
        "chart-2": "oklch(0.556 0.01 260)",
        "chart-3": "oklch(0.439 0.01 260)",
        "chart-4": "oklch(0.371 0.01 260)",
        "chart-5": "oklch(0.283 0.01 260)",
        "sidebar": "oklch(0.25 0.01 260)",
        "sidebar-foreground": "oklch(0.85 0.01 260)",
        "sidebar-primary": "oklch(0.85 0.01 260)",
        "sidebar-primary-foreground": "oklch(0.22 0.01 260)",
        "sidebar-accent": "oklch(0.283 0.01 260)",
        "sidebar-accent-foreground": "oklch(0.85 0.01 260)",
        "sidebar-border": "oklch(1 0 0 / 10%)",
        "sidebar-ring": "oklch(0.556 0.01 260)",
    ]).resolved(isDark: true)

    func testCompletedRowNeverUsesMutedForeground() {
        let color = aiTodoRowTitleColor(status: .completed, palette: Self.lowChromaPalette)
        XCTAssertNotEqual(color, Self.lowChromaPalette.mutedForeground)
        XCTAssertEqual(color, Self.lowChromaPalette.foreground.opacity(0.65))
    }

    func testPendingAndInProgressRowsUseFullForeground() {
        XCTAssertEqual(
            aiTodoRowTitleColor(status: .pending, palette: Self.lowChromaPalette),
            Self.lowChromaPalette.foreground)
        XCTAssertEqual(
            aiTodoRowTitleColor(status: .inProgress, palette: Self.lowChromaPalette),
            Self.lowChromaPalette.foreground)
    }
}
