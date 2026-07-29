import ShadcnUI
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// A pannable, zoomable node graph.
///
/// ```swift
/// var registry = CanvasNodeRegistry<MyData>()
/// registry.register("prompt") { PromptNode(node: $0, context: $1) }
///
/// CanvasView(graph: $graph, registry: registry)
/// ```
public struct CanvasView<Data>: View {
    @Binding private var graph: CanvasGraph<Data>
    private let registry: CanvasNodeRegistry<Data>
    private let showsGrid: Bool

    @Environment(\.shadcnPalette) private var palette

    @State private var viewport = CanvasViewport()
    @State private var hasFitted = false
    /// Graph-space rect being marquee-selected, if any.
    @State private var marquee: CGRect?
    @State private var marqueeOrigin: CGPoint?
    @State private var draggingNode: String?
    @State private var dragAccumulator: CGSize = .zero

    public init(
        graph: Binding<CanvasGraph<Data>>,
        registry: CanvasNodeRegistry<Data>,
        showsGrid: Bool = true
    ) {
        self._graph = graph
        self.registry = registry
        self.showsGrid = showsGrid
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                background

                edgeLayer
                nodeLayer
                marqueeLayer

                // Trackpad pan and pinch zoom. SwiftUI exposes no scroll-delta
                // gesture and `MagnificationGesture` is too coarse to keep the
                // point under the cursor fixed, so this taps NSEvent directly.
                CanvasEventTap(
                    onScroll: { delta in
                        viewport.translation.width += delta.width
                        viewport.translation.height += delta.height
                    },
                    onMagnify: { factor, location in
                        viewport.zoom(to: viewport.zoom * factor, anchor: location)
                    }
                )
                .allowsHitTesting(false)

                CanvasControls(
                    onZoomIn: { zoomAboutCentre(1.2, in: proxy.size) },
                    onZoomOut: { zoomAboutCentre(1 / 1.2, in: proxy.size) },
                    onFit: { fit(in: proxy.size, animated: true) }
                )
                .padding(Space.x4)
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: .bottomLeading
                )
            }
            .contentShape(Rectangle())
            .gesture(canvasDrag(in: proxy.size))
            .onTapGesture { graph.select(nil) }
            .onChange(of: proxy.size) { _, size in
                // Only auto-fit once, and only after something has measured —
                // fitting an unmeasured graph would snap to a garbage rect.
                guard !hasFitted else { return }
                fit(in: size, animated: false)
            }
            .onChange(of: measuredCount) { _, _ in
                guard !hasFitted else { return }
                fit(in: proxy.size, animated: false)
            }
        }
        .clipped()
    }

    private var measuredCount: Int {
        graph.nodes.filter { $0.measuredSize != nil }.count
    }

    // MARK: Layers

    @ViewBuilder
    private var background: some View {
        if showsGrid {
            CanvasGrid(viewport: viewport)
        } else {
            palette.background
        }
    }

    private var edgeLayer: some View {
        Canvas { context, _ in
            for edge in graph.edges {
                guard let ends = graph.endpoints(for: edge) else { continue }
                let path = CanvasGeometry.path(
                    from: viewport.project(ends.start),
                    startPosition: ends.startPosition,
                    to: viewport.project(ends.end),
                    endPosition: ends.endPosition
                )
                context.stroke(
                    path,
                    with: .color(edge.isSelected ? palette.primary : palette.mutedForeground),
                    style: StrokeStyle(
                        lineWidth: (edge.isSelected ? 2 : 1.5) * viewport.zoom,
                        lineCap: .round,
                        dash: edge.type == "temporary" ? [6 * viewport.zoom, 4 * viewport.zoom] : []
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var nodeLayer: some View {
        ForEach(graph.nodes) { node in
            let context = CanvasNodeContext(
                isSelected: node.isSelected,
                isDragging: draggingNode == node.id,
                zoom: viewport.zoom
            )

            registry.view(for: node, context: context)
                .background(NodeMeasurer(id: node.id))
                // Overlays are centre-anchored by default; handle offsets are
                // measured from the node's top-left corner.
                .overlay(alignment: .topLeading) { handleOverlay(for: node) }
                // Scaling about topLeading keeps graph coordinates meaning the
                // node's top-left corner at any zoom.
                .scaleEffect(viewport.zoom, anchor: .topLeading)
                .offset(
                    x: viewport.project(node.position).x,
                    y: viewport.project(node.position).y
                )
                .gesture(nodeDrag(node))
                .onTapGesture { graph.select(node.id) }
        }
        .onPreferenceChange(CanvasNodeSizeKey.self) { sizes in
            for (id, size) in sizes {
                guard var node = graph[id], node.measuredSize != size else { continue }
                node.measuredSize = size
                graph[id] = node
            }
        }
    }

    private func handleOverlay(for node: CanvasNode<Data>) -> some View {
        ForEach(node.handles) { handle in
            CanvasHandleDot(handle: handle, isActive: node.isSelected)
                .offset(handleOffset(handle, size: node.measuredSize ?? .zero))
        }
    }

    /// Positions the dot relative to the node's own (unscaled) bounds.
    private func handleOffset(_ handle: CanvasHandle, size: CGSize) -> CGSize {
        let half = CanvasGeometry.handleSize / 2
        switch handle.position {
        case .left:
            return CGSize(width: -half, height: size.height * handle.offset - half)
        case .right:
            return CGSize(width: size.width - half, height: size.height * handle.offset - half)
        case .top:
            return CGSize(width: size.width * handle.offset - half, height: -half)
        case .bottom:
            return CGSize(width: size.width * handle.offset - half, height: size.height - half)
        }
    }

    @ViewBuilder
    private var marqueeLayer: some View {
        if let marquee {
            let origin = viewport.project(CGPoint(x: marquee.minX, y: marquee.minY))
            Rectangle()
                .fill(palette.primary.opacity(0.1))
                .overlay(Rectangle().strokeBorder(palette.primary, lineWidth: 1))
                .frame(
                    width: marquee.width * viewport.zoom,
                    height: marquee.height * viewport.zoom
                )
                .offset(x: origin.x, y: origin.y)
                .allowsHitTesting(false)
        }
    }

    // MARK: Gestures

    /// Dragging empty canvas marquee-selects, matching AI Elements'
    /// `panOnDrag={false}` — panning is the trackpad's job.
    private func canvasDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = marqueeOrigin ?? viewport.unproject(value.startLocation)
                marqueeOrigin = start
                let current = viewport.unproject(value.location)
                let rect = CGRect(
                    x: min(start.x, current.x),
                    y: min(start.y, current.y),
                    width: abs(current.x - start.x),
                    height: abs(current.y - start.y)
                )
                marquee = rect
                graph.select(in: rect)
            }
            .onEnded { _ in
                marquee = nil
                marqueeOrigin = nil
            }
    }

    private func nodeDrag(_ node: CanvasNode<Data>) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draggingNode != node.id {
                    draggingNode = node.id
                    dragAccumulator = .zero
                    // Dragging an unselected node selects it first, so the
                    // whole selection moves together.
                    if !node.isSelected { graph.select(node.id) }
                }
                // Translation is in view space; the graph moves in graph space.
                let scaled = CGSize(
                    width: value.translation.width / viewport.zoom,
                    height: value.translation.height / viewport.zoom
                )
                let delta = CGSize(
                    width: scaled.width - dragAccumulator.width,
                    height: scaled.height - dragAccumulator.height
                )
                dragAccumulator = scaled
                graph.moveSelected(by: delta)
            }
            .onEnded { _ in
                draggingNode = nil
                dragAccumulator = .zero
            }
    }

    // MARK: Viewport

    private func zoomAboutCentre(_ factor: CGFloat, in size: CGSize) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        withAnimation(.easeOut(duration: 0.15)) {
            viewport.zoom(to: viewport.zoom * factor, anchor: centre)
        }
    }

    private func fit(in size: CGSize, animated: Bool) {
        guard let fitted = graph.fitViewport(in: size) else { return }
        hasFitted = true
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { viewport = fitted }
        } else {
            viewport = fitted
        }
    }
}

// MARK: - Measuring

struct CanvasNodeSizeKey: PreferenceKey {
    static let defaultValue: [String: CGSize] = [:]

    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Publishes a node's laid-out size so edges can find its handles.
private struct NodeMeasurer: View {
    let id: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: CanvasNodeSizeKey.self,
                value: [id: proxy.size]
            )
        }
    }
}

// MARK: - Grid

/// `--color-border` dot grid that pans and zooms with the content.
struct CanvasGrid: View {
    let viewport: CanvasViewport

    @Environment(\.shadcnPalette) private var palette

    var body: some View {
        Canvas { context, size in
            let spacing = 24 * viewport.zoom
            guard spacing > 6 else { return }

            let dot = max(1, 1.5 * viewport.zoom)
            let startX = viewport.translation.width.truncatingRemainder(dividingBy: spacing)
            let startY = viewport.translation.height.truncatingRemainder(dividingBy: spacing)

            var y = startY - spacing
            while y < size.height + spacing {
                var x = startX - spacing
                while x < size.width + spacing {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                        with: .color(palette.border)
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .background(palette.background)
    }
}

// MARK: - Chrome

/// AI Elements' `controls.tsx` — zoom in/out and fit, in a shadcn panel.
public struct CanvasControls: View {
    private let onZoomIn: () -> Void
    private let onZoomOut: () -> Void
    private let onFit: () -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        onZoomIn: @escaping () -> Void,
        onZoomOut: @escaping () -> Void,
        onFit: @escaping () -> Void
    ) {
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.onFit = onFit
    }

    public var body: some View {
        HStack(spacing: Space.x1) {
            ShadcnButton(icon: "plus.magnifyingglass", variant: .ghost, size: .iconSM, action: onZoomIn)
                .shadcnTooltip("Zoom in")
            ShadcnButton(icon: "minus.magnifyingglass", variant: .ghost, size: .iconSM, action: onZoomOut)
                .shadcnTooltip("Zoom out")
            ShadcnButton(icon: "arrow.up.left.and.arrow.down.right", variant: .ghost, size: .iconSM, action: onFit)
                .shadcnTooltip("Fit view")
        }
        .padding(Space.x1)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.card)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
        .shadcnShadow(.sm)
    }
}

/// AI Elements' `panel.tsx` — a floating shadcn surface over the canvas.
public struct CanvasPanel<Content: View>: View {
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) { content }
            .padding(Space.x3)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                    .fill(palette.card)
            )
            .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
            .shadcnShadow(.sm)
    }
}

// MARK: - Event tap

#if canImport(AppKit)
/// Bridges `NSEvent.scrollWheel` and `.magnify` into the canvas.
///
/// AI Elements configures ReactFlow with `panOnScroll`, so the trackpad pans
/// and dragging marquee-selects. SwiftUI has no scroll-delta gesture, and
/// `MagnificationGesture` reports a cumulative factor without a location, which
/// can't keep the point under the cursor fixed.
struct CanvasEventTap: NSViewRepresentable {
    let onScroll: (CGSize) -> Void
    let onMagnify: (CGFloat, CGPoint) -> Void

    func makeNSView(context: Context) -> TapView {
        let view = TapView()
        view.onScroll = onScroll
        view.onMagnify = onMagnify
        return view
    }

    func updateNSView(_ view: TapView, context: Context) {
        view.onScroll = onScroll
        view.onMagnify = onMagnify
    }

    final class TapView: NSView {
        var onScroll: ((CGSize) -> Void)?
        var onMagnify: ((CGFloat, CGPoint) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
                return
            }
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) {
                [weak self] event in
                guard let self, let window = self.window,
                      event.window === window,
                      self.hitTestsSelf(event)
                else { return event }

                switch event.type {
                case .scrollWheel:
                    // Precise deltas are already in points; a legacy mouse
                    // wheel reports lines, so scale it to something usable.
                    let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
                    self.onScroll?(
                        CGSize(
                            width: event.scrollingDeltaX * scale,
                            height: event.scrollingDeltaY * scale
                        )
                    )
                    return nil
                case .magnify:
                    let point = self.convert(event.locationInWindow, from: nil)
                    self.onMagnify?(1 + event.magnification, CGPoint(x: point.x, y: point.y))
                    return nil
                default:
                    return event
                }
            }
        }

        /// Only claim events that landed inside the canvas, so scrolling
        /// elsewhere in the window still works.
        private func hitTestsSelf(_ event: NSEvent) -> Bool {
            let local = convert(event.locationInWindow, from: nil)
            return bounds.contains(local)
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
#else
/// No-op on platforms without AppKit; pinch/scroll fall back to gestures.
struct CanvasEventTap: View {
    let onScroll: (CGSize) -> Void
    let onMagnify: (CGFloat, CGPoint) -> Void
    var body: some View { Color.clear }
}
#endif
