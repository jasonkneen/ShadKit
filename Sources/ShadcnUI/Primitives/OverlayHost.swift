import SwiftUI

/// One floating panel awaiting placement by the root overlay host.
struct ShadcnOverlayItem: Identifiable {
    /// Stable for the lifetime of the presenting control. Regenerating this on
    /// every preference pass makes `ForEach` treat the panel as brand new and
    /// animate it in from the origin — the "flies in from the corner" bug.
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
    /// Known width of the panel, used to place trailing and centered overlays.
    /// A nil width retains the alignment-guide fallback for custom callers.
    let contentWidth: CGFloat?
    /// Whether the host's full-bleed catcher should dismiss this panel on an
    /// outside click. Hover-triggered panels opt out: the catcher sits above
    /// everything in z-order, so leaving it active would steal the pointer
    /// hit-testing the trigger's own `.onHover` needs to detect hover-exit.
    let dismissOnOutsideClick: Bool
    /// Called when the user clicks outside the panel.
    let onDismiss: () -> Void
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

/// A dialog, unlike a menu/select/popover, isn't anchored to a trigger — it
/// centers over the whole host — so it needs no `Anchor<CGRect>` and rides a
/// separate preference list drawn above every anchored item.
struct ShadcnDialogItem: Identifiable {
    let id: UUID
    let width: CGFloat
    let onDismiss: () -> Void
    let content: AnyView
}

struct ShadcnDialogKey: PreferenceKey {
    static let defaultValue: [ShadcnDialogItem] = []

    static func reduce(
        value: inout [ShadcnDialogItem],
        nextValue: () -> [ShadcnDialogItem]
    ) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Presents `content` as a scrimmed dialog centered over the root of the
    /// themed subtree — outside any ancestor's rounded frame or clip, unlike
    /// a plain `.overlay`, which a composer's own clipped chrome cuts off.
    func shadcnDialogOverlay<Content: View>(
        id: UUID,
        isPresented: Bool,
        width: CGFloat,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let dialog = content()
        return preference(
            key: ShadcnDialogKey.self,
            value: isPresented
                ? [ShadcnDialogItem(id: id, width: width, onDismiss: onDismiss, content: AnyView(dialog))]
                : []
        )
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
    ///
    /// - Parameter id: Must be stable while the panel is open. Use a `@State`
    ///   UUID owned by the presenting control — never `UUID()` inline here.
    public func shadcnOverlay<Content: View>(
        id: UUID,
        isPresented: Bool,
        edge: VerticalEdge = .bottom,
        alignment: HorizontalAlignment = .leading,
        gap: CGFloat = 4,
        contentHeight: CGFloat? = nil,
        contentWidth: CGFloat? = nil,
        dismissOnOutsideClick: Bool = true,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) -> some View {
        let panel = content()
        return anchorPreference(key: ShadcnOverlayKey.self, value: .bounds) { anchor in
            guard isPresented else { return [] }
            return [
                ShadcnOverlayItem(
                    id: id,
                    anchor: anchor,
                    edge: edge,
                    alignment: alignment,
                    gap: gap,
                    contentHeight: contentHeight,
                    contentWidth: contentWidth,
                    dismissOnOutsideClick: dismissOnOutsideClick,
                    onDismiss: onDismiss,
                    content: AnyView(panel)
                )
            ]
        }
    }
}

/// Pure placement math for overlay panels. Extracted so tests can pin the
/// "no fly-in / open upward" contract without a live window.
public enum ShadcnOverlayPlacement {
    /// Top-leading origin of the panel in the host's coordinate space.
    /// Trailing and centered placement require the panel width; built-in
    /// overlays provide it explicitly so their right edge cannot leave the host.
    public static func origin(
        trigger: CGRect,
        edge: VerticalEdge,
        alignment: HorizontalAlignment,
        gap: CGFloat,
        contentHeight: CGFloat?,
        contentWidth: CGFloat? = nil
    ) -> CGPoint {
        let x: CGFloat
        switch alignment {
        case .trailing: x = trigger.maxX - (contentWidth ?? 0)
        case .center: x = trigger.midX - (contentWidth ?? 0) / 2
        default: x = trigger.minX
        }
        let y: CGFloat
        switch edge {
        case .top:
            y = trigger.minY - gap - (contentHeight ?? 0)
        default:
            y = trigger.maxY + gap
        }
        return CGPoint(x: x, y: y)
    }

    /// Keeps a panel of known size inside the host. The root host clips at
    /// its own bounds (a rounded pane), so an anchor that is wider than the
    /// visible trigger — or a trigger hugging the host's edge — must not push
    /// the panel off-screen where it is silently cut. Unknown dimensions are
    /// left alone; the origin is never moved past the host's leading/top edge.
    public static func clamped(
        _ origin: CGPoint,
        contentWidth: CGFloat?,
        contentHeight: CGFloat?,
        in host: CGSize
    ) -> CGPoint {
        var result = origin
        if let contentWidth, host.width > 0 {
            result.x = max(0, min(result.x, host.width - contentWidth))
        }
        if let contentHeight, host.height > 0 {
            result.y = max(0, min(result.y, host.height - contentHeight))
        }
        return result
    }

    /// Full placement: flips the preferred edge when it would overflow the
    /// host and the opposite edge fits, then shifts/clamps to stay inside the
    /// host on both axes. Pure and host-size aware, so it holds for any panel
    /// large enough to reach a pane or window boundary — not just the
    /// original narrow menus `origin`/`clamped` were sized for.
    ///
    /// Falls back to `origin` + `clamped` (no flip) when `contentHeight` is
    /// unknown, since flipping needs the panel's height to know whether the
    /// opposite side actually has room.
    public static func resolved(
        trigger: CGRect,
        edge: VerticalEdge,
        alignment: HorizontalAlignment,
        gap: CGFloat,
        contentWidth: CGFloat?,
        contentHeight: CGFloat?,
        in host: CGSize
    ) -> CGPoint {
        var resolvedEdge = edge
        if let contentHeight, host.height > 0 {
            let fitsBelow = trigger.maxY + gap + contentHeight <= host.height
            let fitsAbove = trigger.minY - gap - contentHeight >= 0
            switch edge {
            case .bottom where !fitsBelow && fitsAbove: resolvedEdge = .top
            case .top where !fitsAbove && fitsBelow: resolvedEdge = .bottom
            default: break
            }
        }
        let base = origin(
            trigger: trigger,
            edge: resolvedEdge,
            alignment: alignment,
            gap: gap,
            contentHeight: contentHeight,
            contentWidth: contentWidth
        )
        return clamped(base, contentWidth: contentWidth, contentHeight: contentHeight, in: host)
    }
}

/// Draws whatever the subtree published, above everything else.
///
/// Installed automatically by `shadcnTheme(_:)` / `shadcnSurface(_:)`.
///
/// Placement is pure `offset` from the host's top-leading corner. For
/// `.top`, the caller **must** pass `contentHeight` so the panel sits fully
/// above its trigger (composer pickers do this from their row count). Without
/// it, the panel's top edge lands on the trigger and grows downward over it.
struct ShadcnOverlayHost: ViewModifier {
    /// These are explicit inputs rather than environment reads. This modifier
    /// is attached outside the theme-injection modifiers, so reading the
    /// environment here would resolve ShadKit's default light palette while
    /// the content below correctly renders dark.
    let theme: ShadcnTheme
    let palette: ShadcnPalette
    let colorScheme: ColorScheme
    var surfaceOpacity: Double = 1
    var glassEnabled: Bool = true

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(ShadcnOverlayKey.self) { items in
                menuLayer(items: items)
            }
            .overlayPreferenceValue(ShadcnDialogKey.self) { dialogs in
                dialogLayer(dialogs: dialogs)
            }
    }

    @ViewBuilder
    private func menuLayer(items: [ShadcnOverlayItem]) -> some View {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    // Full-host dismiss layer — not part of the panel's own
                    // size, so a 6000×6000 catcher can't inflate placement.
                    // Skipped when every open item is hover-triggered: this
                    // layer paints above everything, so leaving it active
                    // would intercept the pointer a hover trigger needs to
                    // see its own hover-exit.
                    if let first = items.first(where: { $0.dismissOnOutsideClick }) {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: first.onDismiss)
                    }

                    ForEach(items) { item in
                        let frame = proxy[item.anchor]
                        let origin = ShadcnOverlayPlacement.resolved(
                            trigger: frame,
                            edge: item.edge,
                            alignment: item.alignment,
                            gap: item.gap,
                            contentWidth: item.contentWidth,
                            contentHeight: item.contentHeight,
                            in: proxy.size
                        )

                        // Built-in overlays provide their fixed panel width,
                        // so trailing/center placement is resolved before the
                        // panel is offset. Custom nil-width overlays retain the
                        // alignment-guide fallback below.
                        item.content
                            .environment(\.shadcnTheme, theme)
                            .environment(\.shadcnPalette, palette)
                            .environment(\.shadcnSurfaceOpacity, surfaceOpacity)
                            .environment(\.shadcnGlassEnabled, glassEnabled)
                            .environment(\.colorScheme, colorScheme)
                            .fixedSize()
                            // Preserve alignment for custom overlays that do
                            // not provide a measurable panel width.
                            .alignmentGuide(.leading) { size in
                                guard item.contentWidth == nil else { return 0 }
                                switch item.alignment {
                                case .trailing: return size.width
                                case .center: return size.width / 2
                                default: return 0
                                }
                            }
                            // Placement must not animate: SwiftUI would otherwise
                            // interpolate the offset from zero and the panel flies
                            // in from the corner.
                            .transaction { $0.animation = nil }
                            .offset(x: origin.x, y: origin.y)
                    }
                }
            }
            // The host itself must never intercept input when nothing is open.
            .allowsHitTesting(!items.isEmpty)
    }

    /// Dialogs sit above menus/selects/popovers (`zIndex` on the outer
    /// `overlayPreferenceValue` chain draws later modifiers on top), centered
    /// on the host with a full-bleed scrim, matching the prior in-place
    /// dialog's `Color.black.opacity(0.5)` treatment.
    @ViewBuilder
    private func dialogLayer(dialogs: [ShadcnDialogItem]) -> some View {
        ZStack {
            ForEach(dialogs) { item in
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture(perform: item.onDismiss)

                    item.content
                        .environment(\.shadcnTheme, theme)
                        .environment(\.shadcnPalette, palette)
                        .environment(\.shadcnSurfaceOpacity, surfaceOpacity)
                        .environment(\.shadcnGlassEnabled, glassEnabled)
                        .environment(\.colorScheme, colorScheme)
                        .frame(width: item.width)
                        .fixedSize()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .allowsHitTesting(!dialogs.isEmpty)
    }
}
