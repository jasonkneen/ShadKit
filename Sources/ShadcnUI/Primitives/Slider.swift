import SwiftUI

/// Radix `Slider` as shadcn styles it: a `h-1.5 rounded-full bg-muted` track,
/// a `bg-primary` range, and a `size-4 border-primary bg-background` thumb.
public struct ShadcnSlider: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @State private var isDragging = false

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        step: Double? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
    }

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    public var body: some View {
        GeometryReader { geometry in
            let thumb: CGFloat = 16
            let travel = max(geometry.size.width - thumb, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.muted)
                    .frame(height: 6)

                Capsule()
                    .fill(palette.primary)
                    .frame(width: thumb / 2 + travel * fraction, height: 6)

                Circle()
                    .fill(palette.background)
                    .frame(width: thumb, height: thumb)
                    .overlay(Circle().strokeBorder(palette.primary, lineWidth: 1))
                    .shadcnShadow(.xs)
                    .offset(x: travel * fraction)
            }
            .frame(height: thumb)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard isEnabled else { return }
                        isDragging = true
                        // The thumb centre tracks the pointer, so the usable
                        // travel excludes half a thumb at each end.
                        let x = min(max(drag.location.x - thumb / 2, 0), travel)
                        update(to: x / travel)
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: 20)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func update(to newFraction: Double) {
        let span = range.upperBound - range.lowerBound
        var next = range.lowerBound + newFraction * span
        if let step, step > 0 {
            next = (next / step).rounded() * step
        }
        value = min(max(next, range.lowerBound), range.upperBound)
    }
}

/// A labelled slider row with its value read out on the right — the shape most
/// settings forms want.
public struct ShadcnSliderRow: View {
    private let title: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double?
    private let format: (Double) -> String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        format: @escaping (Double) -> String = { String(format: "%.2f", $0) }
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    public var body: some View {
        HStack(spacing: Space.x4) {
            Text(title)
                .font(theme.typography.sans(theme.typography.sm))
                .foregroundStyle(palette.foreground)
                .frame(width: 110, alignment: .leading)

            ShadcnSlider(value: $value, in: range, step: step)

            Text(format(value))
                .font(theme.typography.mono(theme.typography.xs))
                .foregroundStyle(palette.mutedForeground)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
