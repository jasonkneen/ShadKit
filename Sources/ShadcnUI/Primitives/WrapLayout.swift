import SwiftUI

/// `flex flex-wrap` — lays children out in rows, wrapping at the container's
/// width.
///
/// Used wherever the React source relies on flex wrapping: attachment rows,
/// search-result pills, suggestion chips.
public struct ShadcnWrapLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    public var alignment: HorizontalAlignment

    public init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)

        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height
        } + lineSpacing * CGFloat(max(0, rows.count - 1))

        let width = rows.map(\.width).max() ?? 0
        return CGSize(
            width: proposal.width ?? width,
            height: height
        )
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x: CGFloat
            switch alignment {
            case .center: x = bounds.minX + (bounds.width - row.width) / 2
            case .trailing: x = bounds.maxX - row.width
            default: x = bounds.minX
            }

            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    // MARK: - Row packing

    private struct Element {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var elements: [Element] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.elements.isEmpty ? size.width : current.width + spacing + size.width

            if needed > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = Row()
                current.elements = [Element(index: index, size: size)]
                current.width = size.width
                current.height = size.height
            } else {
                current.elements.append(Element(index: index, size: size))
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }

        if !current.elements.isEmpty { rows.append(current) }
        return rows
    }
}
