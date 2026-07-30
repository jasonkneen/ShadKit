import SwiftUI

/// One floating panel awaiting placement by the root overlay host.
struct ShadcnOverlayItem: Identifiable {
    let id: UUID
    /// Bounds of the trigger, resolved against the host's coordinate space.
    let anchor: Anchor<CGRect>
    let edge: VerticalEdge
    let alignment: HorizontalAlignment
    let gap: CGFloat
    /// Panel height, when the caller can compute it (a menu knows its row
    /// count). Required for `.top`: placing a panel above its trigger means
    /// offsetting by its own height, and measuring it during layout doesn't
    /// work — SwiftUI discards state written from a preference reader.
    let contentHeight: CGFloat?
    let content: AnyView
}

struct ShadcnOverlayKey: PreferenceKey {
    static let defaultValue: [ShadcnOverlayItem] = []

    static func reduce(
        value: inout [ShadcnOverlayItem],
        nextValue: () -> [ShadcnOverlayItem]
    ) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Presents `content` anchored to this view but *drawn at the root of the
    /// themed subtree*.
    ///
    /// `zIndex` can only order a view against its immediate siblings, so an
    /// inline overlay is painted over by anything that comes later in an
    /// ancestor stack. Publishing the panel as a preference and drawing it once
    /// at the root sidesteps stacking entirely — the panel is genuinely the
    /// last thing drawn, whatever it's nested in.
    public func shadcnOverlay<Content: View>(
        isPresented: Bool,
        edge: VerticalEdge = .bottom,
        alignment: HorizontalAlignment = .leading,
        gap: CGFloat = 4,
        contentHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let panel = content()
        return anchorPreference(key: ShadcnOverlayKey.self, value: .bounds) { anchor in
            guard isPresented else { return [] }
            return [
                ShadcnOverlayItem(
                    id: UUID(),
                    anchor: anchor,
                    edge: edge,
                    alignment: alignment,
                    gap: gap,
                    contentHeight: contentHeight,
                    content: AnyView(panel)
                )
            ]
        }
    }
}

/// Draws whatever the subtree published, above everything else.
///
/// Installed automatically by `shadcnTheme(_:)` / `shadcnSurface(_:)`.
struct ShadcnOverlayHost: ViewModifier {
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(ShadcnOverlayKey.self) { items in
            GeometryReader { proxy in
                ForEach(items) { item in
                    let frame = proxy[item.anchor]
                    item.content
                        .fixedSize()

                        .alignmentGuide(.leading) { size in
                            switch item.alignment {
                            case .trailing: size.width
                            case .center: size.width / 2
                            default: 0
                            }
                        }
                        // Opening upward needs the panel's own height, which
                        // isn't known at placement time. Rather than measure it,
                        // give the panel a container that *ends* at the
                        // trigger's top and bottom-align inside it — SwiftUI
                        // does the arithmetic during layout.
                        // `.top` is plumbed but does not render, and the cause
                        // is upstream of placement: with the offset arithmetic
                        // now correct (the caller states the panel height, so
                        // nothing is measured during layout) the panel still
                        // appears nowhere. Six approaches ruled out. Something
                        // about `.top` prevents the overlay being emitted at
                        // all — next step is a breakpoint in this closure to see
                        // whether the item even arrives.
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topLeading
                        )
                        .offset(
                            x: originX(for: item, trigger: frame),
                            y: item.edge == .bottom
                                ? frame.maxY + item.gap
                                : frame.minY - item.gap - (item.contentHeight ?? 0)
                        )
                }
            }
            // The host itself must never intercept input; only the panels do.
            .allowsHitTesting(!items.isEmpty)
        }
    }

    private func originX(for item: ShadcnOverlayItem, trigger: CGRect) -> CGFloat {
        switch item.alignment {
        case .trailing: trigger.maxX
        case .center: trigger.midX
        default: trigger.minX
        }
    }
}
