import CoreGraphics
import XCTest
@testable import CanvasUI

/// The canvas is mostly coordinate maths, which is exactly the part that fails
/// silently on screen. These pin it.
final class CanvasTests: XCTestCase {

    private func graph() -> CanvasGraph<String> {
        CanvasGraph(
            nodes: [
                CanvasNode(
                    id: "a", position: CGPoint(x: 0, y: 0), data: "a",
                    measuredSize: CGSize(width: 200, height: 100)),
                CanvasNode(
                    id: "b", position: CGPoint(x: 400, y: 200), data: "b",
                    measuredSize: CGSize(width: 200, height: 100)),
            ],
            edges: [CanvasEdge(id: "e", source: "a", target: "b")]
        )
    }

    // MARK: - Viewport

    func testProjectAndUnprojectAreInverses() {
        var viewport = CanvasViewport(translation: CGSize(width: 37, height: -19), zoom: 1.75)
        let point = CGPoint(x: 123, y: 456)
        let round = viewport.unproject(viewport.project(point))
        XCTAssertEqual(round.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(round.y, point.y, accuracy: 0.0001)
        viewport.zoom = 1
    }

    func testZoomKeepsTheAnchorPointFixed() {
        var viewport = CanvasViewport(translation: CGSize(width: 10, height: 10), zoom: 1)
        let anchor = CGPoint(x: 300, y: 200)
        let graphPointUnderAnchor = viewport.unproject(anchor)

        viewport.zoom(to: 2.2, anchor: anchor)

        // The whole point of anchored zoom: what was under the cursor stays there.
        let after = viewport.project(graphPointUnderAnchor)
        XCTAssertEqual(after.x, anchor.x, accuracy: 0.0001)
        XCTAssertEqual(after.y, anchor.y, accuracy: 0.0001)
    }

    func testZoomClampsToBounds() {
        var viewport = CanvasViewport()
        viewport.zoom(to: 99, anchor: .zero)
        XCTAssertEqual(viewport.zoom, CanvasViewport.maxZoom)
        viewport.zoom(to: 0.0001, anchor: .zero)
        XCTAssertEqual(viewport.zoom, CanvasViewport.minZoom)
    }

    // MARK: - Fit

    func testFitViewIsNilUntilSomethingHasMeasured() {
        var unmeasured = CanvasGraph<String>(
            nodes: [CanvasNode(id: "a", position: .zero, data: "a")]
        )
        XCTAssertNil(unmeasured.contentBounds)
        // Must degrade rather than snap to a garbage rect on the first frame.
        XCTAssertNil(unmeasured.fitViewport(in: CGSize(width: 800, height: 600)))

        unmeasured.nodes[0].measuredSize = CGSize(width: 100, height: 50)
        XCTAssertNotNil(unmeasured.fitViewport(in: CGSize(width: 800, height: 600)))
    }

    func testFitCentresTheContent() throws {
        let size = CGSize(width: 1000, height: 800)
        let viewport = try XCTUnwrap(graph().fitViewport(in: size))
        let bounds = try XCTUnwrap(graph().contentBounds)

        let centre = viewport.project(CGPoint(x: bounds.midX, y: bounds.midY))
        XCTAssertEqual(centre.x, size.width / 2, accuracy: 0.5)
        XCTAssertEqual(centre.y, size.height / 2, accuracy: 0.5)
    }

    func testContentBoundsSpansEveryNode() throws {
        let bounds = try XCTUnwrap(graph().contentBounds)
        XCTAssertEqual(bounds.minX, 0)
        XCTAssertEqual(bounds.minY, 0)
        XCTAssertEqual(bounds.maxX, 600)
        XCTAssertEqual(bounds.maxY, 300)
    }

    // MARK: - Handle anchors

    func testRightAnchorAddsAFullHandleWidth() {
        // Matches edge.tsx, which is origin-top-left and adds the whole handle
        // width on the right — half would land arrowheads short.
        let frame = CGRect(x: 10, y: 20, width: 200, height: 100)
        let right = CanvasHandle(id: "s", kind: .source, position: .right)
        let anchor = CanvasGeometry.anchor(of: right, nodeFrame: frame)
        XCTAssertEqual(anchor.x, 10 + 200 + CanvasGeometry.handleSize)
        XCTAssertEqual(anchor.y, 20 + 50)
    }

    func testLeftAnchorSitsOnTheEdge() {
        let frame = CGRect(x: 10, y: 20, width: 200, height: 100)
        let left = CanvasHandle(id: "t", kind: .target, position: .left)
        let anchor = CanvasGeometry.anchor(of: left, nodeFrame: frame)
        XCTAssertEqual(anchor.x, 10)
        XCTAssertEqual(anchor.y, 70)
    }

    func testHandleOffsetShiftsAlongTheEdge() {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let quarter = CanvasHandle(id: "t", kind: .target, position: .left, offset: 0.25)
        XCTAssertEqual(CanvasGeometry.anchor(of: quarter, nodeFrame: frame).y, 25)
    }

    func testEndpointsAreNilWhileAnEndpointIsUnmeasured() {
        var g = graph()
        g.nodes[1].measuredSize = nil
        XCTAssertNil(g.endpoints(for: g.edges[0]))
    }

    // MARK: - Curve

    func testCurveStartsAndEndsOnItsAnchors() {
        let start = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 300, y: 200)
        let first = CanvasGeometry.point(
            at: 0, from: start, startPosition: .right, to: end, endPosition: .left)
        let last = CanvasGeometry.point(
            at: 1, from: start, startPosition: .right, to: end, endPosition: .left)
        XCTAssertEqual(first.x, start.x, accuracy: 0.0001)
        XCTAssertEqual(last.x, end.x, accuracy: 0.0001)
        XCTAssertEqual(last.y, end.y, accuracy: 0.0001)
    }

    func testCurveLeavesRightHandleGoingRight() {
        let start = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 300, y: 200)
        let justAfterStart = CanvasGeometry.point(
            at: 0.05, from: start, startPosition: .right, to: end, endPosition: .left)
        XCTAssertGreaterThan(justAfterStart.x, start.x)
    }

    // MARK: - Selection and movement

    func testMarqueeSelectsOnlyIntersectingNodes() {
        var g = graph()
        g.select(in: CGRect(x: -10, y: -10, width: 120, height: 120))
        XCTAssertEqual(g.selectedNodeIDs, ["a"])
    }

    func testDraggingMovesTheWholeSelection() {
        var g = graph()
        g.select("a")
        g.nodes[1].isSelected = true
        g.moveSelected(by: CGSize(width: 10, height: -5))
        XCTAssertEqual(g.nodes[0].position, CGPoint(x: 10, y: -5))
        XCTAssertEqual(g.nodes[1].position, CGPoint(x: 410, y: 195))
    }

    func testUndraggableNodesStayPut() {
        var g = graph()
        g.nodes[0].isDraggable = false
        g.nodes[0].isSelected = true
        g.moveSelected(by: CGSize(width: 50, height: 50))
        XCTAssertEqual(g.nodes[0].position, .zero)
    }

    func testDeletingNodesTakesTheirEdges() {
        var g = graph()
        g.select("a")
        g.removeSelected()
        XCTAssertEqual(g.nodes.map(\.id), ["b"])
        XCTAssertTrue(g.edges.isEmpty, "an edge must not outlive its endpoint")
    }

    func testSelectingNilClearsEverything() {
        var g = graph()
        g.select("a")
        g.select(nil)
        XCTAssertTrue(g.selectedNodeIDs.isEmpty)
    }
}
