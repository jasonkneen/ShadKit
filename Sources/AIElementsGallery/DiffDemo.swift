import AIElementsUI
import ShadcnUI
import SwiftUI

struct DiffDemo: View {
    @State private var mode: AIDiffMode = .unified

    private let sample = """
    @@ -12,9 +12,9 @@ public struct OKLCH {
     /// Linear-light sRGB.
     public var linearSRGB: (r: Double, g: Double, b: Double) {
         let (labL, labA, labB) = oklab
    -    let lPrime = labL + 0.3963 * labA + 0.2158 * labB
    -    let mPrime = labL - 0.1055 * labA - 0.0638 * labB
    +    let lPrime = labL + 0.396337777 * labA + 0.215803757 * labB
    +    let mPrime = labL - 0.105561345 * labA - 0.063854172 * labB
         let long = lPrime * lPrime * lPrime
         return (r: 4.0767 * long, g: 0, b: 0)
     }
     // unchanged tail
     // unchanged tail
     // unchanged tail
     // unchanged tail
     // unchanged tail
     // unchanged tail
     // unchanged tail
    """

    var body: some View {
        GalleryHeading(
            title: "Diff",
            subtitle: "Unified and split, word-level highlighting, collapsible context."
        )

        GalleryBlock("Mode") {
            ShadcnTabs(
                selection: Binding(
                    get: { mode == .unified ? 0 : 1 },
                    set: { mode = $0 == 0 ? .unified : .split }
                ),
                items: [(0, "Unified"), (1, "Split")]
            )
        }

        GalleryBlock("Diff") {
            AIDiffView(unified: sample, mode: mode, language: "swift")
                .frame(maxWidth: 720)
        }

        GalleryBlock("Font size") {
            AIDiffView(unified: sample, mode: mode, language: "swift", fontSize: 11)
                .frame(maxWidth: 720)
        }

        GalleryBlock("Side by side") {
            AIDiffView(unified: sample, mode: .sideBySide, language: "swift")
                .frame(maxWidth: 720)
        }
    }
}
