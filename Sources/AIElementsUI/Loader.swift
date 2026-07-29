import ShadcnUI
import SwiftUI

/// AI Elements' `Loader` — ten spokes fading from full to 10% opacity,
/// spinning clockwise.
///
/// The source is a hand-drawn 16×16 SVG: spokes run from radius 4 to radius 8
/// with a 1.5 stroke, stepping 36° anticlockwise as the opacity drops, so the
/// bright end leads the spin.
public struct AILoader: View {
    private let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    private static let spokeCount = 10

    public init(size: CGFloat = 16) {
        self.size = size
    }

    public var body: some View {
        // Everything is expressed against the SVG's 16pt viewBox and scaled.
        let unit = size / 16

        ZStack {
            ForEach(0..<Self.spokeCount, id: \.self) { index in
                Rectangle()
                    .frame(width: 1.5 * unit, height: 4 * unit)
                    .offset(y: -6 * unit)
                    .rotationEffect(.degrees(Double(index) * -36))
                    .opacity(1.0 - Double(index) * 0.1)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(angle))
        .onAppear {
            guard !reduceMotion else { return }
            // Tailwind's `animate-spin` is a linear 1s revolution.
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
        .accessibilityLabel("Loading")
    }
}

/// AI Elements' `Shimmer` — a band of the `background` token sweeping across
/// text painted in `muted-foreground`.
///
/// Reproduces the original's two stacked background layers clipped to the
/// glyphs, so the band reads as a highlight in light mode and a shadow in dark,
/// exactly as the CSS does.
public struct AIShimmer: View {
    private let text: String
    private let font: Font?
    private let duration: Double
    /// Points of feather on each side of the band, per character.
    private let spread: CGFloat

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public init(
        _ text: String,
        font: Font? = nil,
        duration: Double = 2,
        spread: CGFloat = 2
    ) {
        self.text = text
        self.font = font
        self.duration = duration
        self.spread = spread
    }

    private var resolvedFont: Font {
        font ?? theme.typography.sans(theme.typography.sm)
    }

    public var body: some View {
        Text(text)
            .font(resolvedFont)
            .foregroundStyle(palette.mutedForeground)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        let bandWidth = max(
                            CGFloat(text.count) * spread * 2,
                            geometry.size.width * 0.4
                        )
                        LinearGradient(
                            colors: [.clear, palette.background, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: bandWidth)
                        // Travels from fully off the trailing edge to fully off
                        // the leading edge.
                        .offset(x: phase * (geometry.size.width + bandWidth))
                        .frame(width: geometry.size.width, alignment: .leading)
                    }
                    .mask(Text(text).font(resolvedFont))
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
