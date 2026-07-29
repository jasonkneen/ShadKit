import CoreGraphics
import XCTest
@testable import CanvasUI

/// Viewport and graph mutation edge cases beyond the happy paths already
/// covered — the states a canvas actually gets into while being used.
final class CanvasViewportTests: XCTestCase {

    private func graph() -> CanvasGraph<String> {
        CanvasGraph(
            nodes: [
                CanvasNode(id: "a", position: .zero, data: "a",
                           measuredSize: CGSize(width: 100, height: 50)),
                CanvasNode(id: "b", position: CGPoint(x: 300, y: 0), data: "b",
                           measuredSize: CGSize(width: 100, height: 50)),
            ],
            edges: [CanvasEdge(id: "e", source: "a", target: "b")])
    }

    func testZoomAnchoredAtTheOriginStillHoldsTheAnchor() {
        var viewport = CanvasViewport()
        let anchor = CGPoint.zero
        let before = viewport.unproject(anchor)
        viewport.zoom(to: 2, anchor: anchor)
        let after = viewport.project(before)
        XCTAssertEqual(after.x, anchor.x, accuracy: 0.0001)
        XCTAssertEqual(after.y, anchor.y, accuracy: 0.0001)
    }

    func testRepeatedZoomingDoesNotDrift() {
        var viewport = CanvasViewport()
        let anchor = CGPoint(x: 400, y: 300)
        let graphPoint = viewport.unproject(anchor)
        for _ in 0..<20 {
            viewport.zoom(to: viewport.zoom * 1.1, anchor: anchor)
            viewport.zoom(to: viewport.zoom / 1.1, anchor: anchor)
        }
        let after = viewport.project(graphPoint)
        XCTAssertEqual(after.x, anchor.x, accuracy: 0.01, "zoom must not accumulate error")
        XCTAssertEqual(after.y, anchor.y, accuracy: 0.01)
    }

    func testFitOfASingleNodeCentresIt() throws {
        var single = CanvasGraph<String>(
            nodes: [CanvasNode(id: "a", position: CGPoint(x: 500, y: 500), data: "a",
                               measuredSize: CGSize(width: 100, height: 100))])
        let size = CGSize(width: 800, height: 600)
        let viewport = try XCTUnwrap(single.fitViewport(in: size))
        let centre = viewport.project(CGPoint(x: 550, y: 550))
        XCTAssertEqual(centre.x, 400, accuracy: 0.5)
        XCTAssertEqual(centre.y, 300, accuracy: 0.5)
        single.nodes.removeAll()
    }

    func testFitRefusesAViewportSmallerThanItsPadding() {
        XCTAssertNil(graph().fitViewport(in: CGSize(width: 10, height: 10)))
    }

    func testFitClampsZoomForATinyGraph() throws {
        // A single small node must not zoom to 40x just to fill the viewport.
        let tiny = CanvasGraph<String>(
            nodes: [CanvasNode(id: "a", position: .zero, data: "a",
                               measuredSize: CGSize(width: 10, height: 10))])
        let viewport = try XCTUnwrap(tiny.fitViewport(in: CGSize(width: 1000, height: 800)))
        XCTAssertLessThanOrEqual(viewport.zoom, CanvasViewport.maxZoom)
    }

    func testSubscriptRoundTrips() {
        var g = graph()
        var node = try! XCTUnwrap(g["a"])
        node.position = CGPoint(x: 42, y: 42)
        g["a"] = node
        XCTAssertEqual(g["a"]?.position, CGPoint(x: 42, y: 42))
    }

    func testAssigningAnUnknownIDIsANoOp() {
        var g = graph()
        let before = g.nodes.count
        g["nope"] = CanvasNode(id: "nope", position: .zero, data: "x")
        XCTAssertEqual(g.nodes.count, before, "assignment must not insert")
    }

    func testAdditiveSelectionAccumulates() {
        var g = graph()
        g.select("a")
        g.select("b", additive: true)
        XCTAssertEqual(Set(g.selectedNodeIDs), ["a", "b"])
    }

    func testNonAdditiveSelectionReplaces() {
        var g = graph()
        g.select("a")
        g.select("b")
        XCTAssertEqual(g.selectedNodeIDs, ["b"])
    }

    func testMarqueeMissingEverythingClearsSelection() {
        var g = graph()
        g.select("a")
        g.select(in: CGRect(x: 5000, y: 5000, width: 10, height: 10))
        XCTAssertTrue(g.selectedNodeIDs.isEmpty)
    }

    func testUnmeasuredNodesAreNeverMarqueeSelected() {
        var g = graph()
        g.nodes[0].measuredSize = nil
        g.select(in: CGRect(x: -100, y: -100, width: 1000, height: 1000))
        XCTAssertFalse(g.selectedNodeIDs.contains("a"))
    }

    func testDeletingWithNoSelectionChangesNothing() {
        var g = graph()
        g.removeSelected()
        XCTAssertEqual(g.nodes.count, 2)
        XCTAssertEqual(g.edges.count, 1)
    }

    func testMovingAnUnknownNodeIsANoOp() {
        var g = graph()
        g.move("nope", by: CGSize(width: 10, height: 10))
        XCTAssertEqual(g.nodes[0].position, .zero)
    }
}
