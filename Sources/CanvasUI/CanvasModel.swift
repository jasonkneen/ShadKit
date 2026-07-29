import CoreGraphics
import Foundation

/// Where a handle sits on a node. Mirrors ReactFlow's `Position`.
public enum CanvasHandlePosition: String, Sendable, CaseIterable {
    case top, right, bottom, left
}

/// Whether a handle starts or accepts a connection.
public enum CanvasHandleKind: String, Sendable {
    case source
    case target
}

/// One connection point on a node.
public struct CanvasHandle: Identifiable, Hashable, Sendable {
    public var id: String
    public var kind: CanvasHandleKind
    public var position: CanvasHandlePosition
    /// 0...1 along the node's edge. 0.5 is centred.
    public var offset: CGFloat

    public init(
        id: String,
        kind: CanvasHandleKind,
        position: CanvasHandlePosition,
        offset: CGFloat = 0.5
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.offset = offset
    }

    /// The target-left / source-right pair `node.tsx` hardcodes.
    public static func standard() -> [CanvasHandle] {
        [
            CanvasHandle(id: "target", kind: .target, position: .left),
            CanvasHandle(id: "source", kind: .source, position: .right),
        ]
    }
}

/// A node in the graph.
///
/// `Data` is yours — the canvas only needs position, size and handles.
public struct CanvasNode<Data>: Identifiable {
    public var id: String
    /// Selects the view from the registry, the analogue of ReactFlow's `type`.
    public var type: String
    public var position: CGPoint
    public var data: Data
    public var handles: [CanvasHandle]
    /// Filled in once the node has laid itself out. Edges can't route until
    /// every endpoint has measured, so this stays nil for the first frame.
    public var measuredSize: CGSize?
    public var isSelected: Bool
    public var isDraggable: Bool

    public init(
        id: String,
        type: String = "default",
        position: CGPoint,
        data: Data,
        handles: [CanvasHandle] = CanvasHandle.standard(),
        measuredSize: CGSize? = nil,
        isSelected: Bool = false,
        isDraggable: Bool = true
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.data = data
        self.handles = handles
        self.measuredSize = measuredSize
        self.isSelected = isSelected
        self.isDraggable = isDraggable
    }

    /// Rect in graph space. Zero-sized until the node has measured.
    public var frame: CGRect {
        CGRect(origin: position, size: measuredSize ?? .zero)
    }
}

/// A connection between two handles.
public struct CanvasEdge: Identifiable, Hashable, Sendable {
    public var id: String
    public var source: String
    public var target: String
    public var sourceHandle: String
    public var targetHandle: String
    /// Selects the edge renderer; `animated` and `temporary` ship with the kit.
    public var type: String
    public var label: String?
    public var isSelected: Bool

    public init(
        id: String,
        source: String,
        target: String,
        sourceHandle: String = "source",
        targetHandle: String = "target",
        type: String = "default",
        label: String? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.sourceHandle = sourceHandle
        self.targetHandle = targetHandle
        self.type = type
        self.label = label
        self.isSelected = isSelected
    }
}

/// Pan and zoom. Mirrors ReactFlow's `Viewport`.
public struct CanvasViewport: Equatable, Sendable {
    public var translation: CGSize
    public var zoom: CGFloat

    public init(translation: CGSize = .zero, zoom: CGFloat = 1) {
        self.translation = translation
        self.zoom = zoom
    }

    public static let minZoom: CGFloat = 0.2
    public static let maxZoom: CGFloat = 2.5

    /// Graph space -> view space.
    public func project(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * zoom + translation.width,
            y: point.y * zoom + translation.height
        )
    }

    /// View space -> graph space.
    public func unproject(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - translation.width) / zoom,
            y: (point.y - translation.height) / zoom
        )
    }

    /// Zooms about a fixed point in view space, so the content under the
    /// pointer stays put — the behaviour trackpad zoom needs.
    public mutating func zoom(to newZoom: CGFloat, anchor: CGPoint) {
        let clamped = min(max(newZoom, Self.minZoom), Self.maxZoom)
        let graphAnchor = unproject(anchor)
        zoom = clamped
        translation = CGSize(
            width: anchor.x - graphAnchor.x * clamped,
            height: anchor.y - graphAnchor.y * clamped
        )
    }
}

/// The graph itself.
public struct CanvasGraph<Data> {
    public var nodes: [CanvasNode<Data>]
    public var edges: [CanvasEdge]

    public init(nodes: [CanvasNode<Data>] = [], edges: [CanvasEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }

    public subscript(nodeID: String) -> CanvasNode<Data>? {
        get { nodes.first { $0.id == nodeID } }
        set {
            guard let newValue, let index = nodes.firstIndex(where: { $0.id == nodeID })
            else { return }
            nodes[index] = newValue
        }
    }

    /// Bounding box of every measured node, in graph space.
    ///
    /// `nil` while nothing has measured yet, which is what lets `fitView`
    /// degrade instead of snapping to a garbage rect on the first frame.
    public var contentBounds: CGRect? {
        let measured = nodes.filter { $0.measuredSize != nil }
        guard !measured.isEmpty else { return nil }
        return measured.dropFirst().reduce(measured[0].frame) { $0.union($1.frame) }
    }

    /// The viewport that fits everything into `size`, with padding.
    public func fitViewport(in size: CGSize, padding: CGFloat = 48) -> CanvasViewport? {
        guard let bounds = contentBounds, bounds.width > 0, bounds.height > 0,
              size.width > padding * 2, size.height > padding * 2
        else { return nil }

        let available = CGSize(
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )
        let scale = min(
            available.width / bounds.width,
            available.height / bounds.height
        )
        let zoom = min(max(scale, CanvasViewport.minZoom), CanvasViewport.maxZoom)

        // Centre the content's midpoint in the viewport.
        let midpoint = CGPoint(x: bounds.midX, y: bounds.midY)
        return CanvasViewport(
            translation: CGSize(
                width: size.width / 2 - midpoint.x * zoom,
                height: size.height / 2 - midpoint.y * zoom
            ),
            zoom: zoom
        )
    }

    public mutating func select(_ nodeID: String?, additive: Bool = false) {
        for index in nodes.indices {
            let hit = nodes[index].id == nodeID
            nodes[index].isSelected = additive ? (nodes[index].isSelected || hit) : hit
        }
        if nodeID == nil, !additive {
            for index in edges.indices { edges[index].isSelected = false }
        }
    }

    /// Selects everything intersecting a rect in graph space — the marquee.
    public mutating func select(in rect: CGRect) {
        for index in nodes.indices {
            nodes[index].isSelected = nodes[index].measuredSize != nil
                && nodes[index].frame.intersects(rect)
        }
    }

    public var selectedNodeIDs: [String] {
        nodes.filter(\.isSelected).map(\.id)
    }

    /// Removes nodes and any edge that touched them.
    public mutating func removeSelected() {
        let doomed = Set(selectedNodeIDs)
        guard !doomed.isEmpty else { return }
        nodes.removeAll { doomed.contains($0.id) }
        edges.removeAll { doomed.contains($0.source) || doomed.contains($0.target) }
    }

    public mutating func move(_ nodeID: String, by delta: CGSize) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }),
              nodes[index].isDraggable
        else { return }
        nodes[index].position.x += delta.width
        nodes[index].position.y += delta.height
    }

    /// Moves every selected node, so dragging one drags the selection.
    public mutating func moveSelected(by delta: CGSize) {
        for index in nodes.indices where nodes[index].isSelected && nodes[index].isDraggable {
            nodes[index].position.x += delta.width
            nodes[index].position.y += delta.height
        }
    }
}
