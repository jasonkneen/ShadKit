import CoreGraphics
import SwiftUI

/// Where handles sit and how edges route between them.
public enum CanvasGeometry {
    /// `size-3` — the handle diameter `node.tsx` uses.
    public static let handleSize: CGFloat = 12

    /// Anchor point of a handle, in graph space.
    ///
    /// Offsets are origin-top-left and match `edge.tsx`: the right anchor adds a
    /// *full* handle width rather than half, and the bottom anchor a full
    /// height. Getting this wrong lands arrowheads slightly off the handle.
    public static func anchor(
        of handle: CanvasHandle,
        nodeFrame frame: CGRect
    ) -> CGPoint {
        switch handle.position {
        case .left:
            CGPoint(
                x: frame.minX,
                y: frame.minY + frame.height * handle.offset
            )
        case .right:
            CGPoint(
                x: frame.minX + frame.width + handleSize,
                y: frame.minY + frame.height * handle.offset
            )
        case .top:
            CGPoint(
                x: frame.minX + frame.width * handle.offset,
                y: frame.minY
            )
        case .bottom:
            CGPoint(
                x: frame.minX + frame.width * handle.offset,
                y: frame.minY + frame.height + handleSize
            )
        }
    }

    /// The bezier ReactFlow draws between two handles.
    ///
    /// Control points extend along each handle's axis, scaled by the gap, so
    /// close nodes get a gentle curve and distant ones a sweeping one.
    public static func path(
        from start: CGPoint,
        startPosition: CanvasHandlePosition,
        to end: CGPoint,
        endPosition: CanvasHandlePosition
    ) -> Path {
        var path = Path()
        path.move(to: start)
        let (c1, c2) = controlPoints(
            from: start, startPosition: startPosition,
            to: end, endPosition: endPosition
        )
        path.addCurve(to: end, control1: c1, control2: c2)
        return path
    }

    static func controlPoints(
        from start: CGPoint,
        startPosition: CanvasHandlePosition,
        to end: CGPoint,
        endPosition: CanvasHandlePosition
    ) -> (CGPoint, CGPoint) {
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        // Clamped so very short edges don't loop back on themselves.
        let strength = max(min(max(dx, dy) * 0.5, 220), 24)

        func offset(_ point: CGPoint, _ position: CanvasHandlePosition) -> CGPoint {
            switch position {
            case .left: CGPoint(x: point.x - strength, y: point.y)
            case .right: CGPoint(x: point.x + strength, y: point.y)
            case .top: CGPoint(x: point.x, y: point.y - strength)
            case .bottom: CGPoint(x: point.x, y: point.y + strength)
            }
        }

        return (offset(start, startPosition), offset(end, endPosition))
    }

    /// Point at `t` along the curve — used by the animated edge's travelling
    /// dot, which samples the path rather than relying on SVG `animateMotion`.
    public static func point(
        at t: CGFloat,
        from start: CGPoint,
        startPosition: CanvasHandlePosition,
        to end: CGPoint,
        endPosition: CanvasHandlePosition
    ) -> CGPoint {
        let (c1, c2) = controlPoints(
            from: start, startPosition: startPosition,
            to: end, endPosition: endPosition
        )
        let u = 1 - t
        // Cubic Bézier.
        let x = u * u * u * start.x
            + 3 * u * u * t * c1.x
            + 3 * u * t * t * c2.x
            + t * t * t * end.x
        let y = u * u * u * start.y
            + 3 * u * u * t * c1.y
            + 3 * u * t * t * c2.y
            + t * t * t * end.y
        return CGPoint(x: x, y: y)
    }
}

extension CanvasGraph {
    /// Resolved endpoints for an edge, or `nil` while either node is unmeasured.
    func endpoints(
        for edge: CanvasEdge
    ) -> (start: CGPoint, startPosition: CanvasHandlePosition,
          end: CGPoint, endPosition: CanvasHandlePosition)? {
        guard let source = self[edge.source], source.measuredSize != nil,
              let target = self[edge.target], target.measuredSize != nil,
              let sourceHandle = source.handles.first(where: { $0.id == edge.sourceHandle })
                ?? source.handles.first(where: { $0.kind == .source }),
              let targetHandle = target.handles.first(where: { $0.id == edge.targetHandle })
                ?? target.handles.first(where: { $0.kind == .target })
        else { return nil }

        return (
            CanvasGeometry.anchor(of: sourceHandle, nodeFrame: source.frame),
            sourceHandle.position,
            CanvasGeometry.anchor(of: targetHandle, nodeFrame: target.frame),
            targetHandle.position
        )
    }
}
