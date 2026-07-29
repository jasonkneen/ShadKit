import SwiftUI
import XCTest
@testable import CanvasUI

/// The node registry is the extensibility contract — ReactFlow's
/// `nodeTypes={{ custom: MyNode }}`. Its dispatch had no coverage.
final class CanvasRegistryTests: XCTestCase {

    private func node(_ type: String) -> CanvasNode<String> {
        CanvasNode(id: type, type: type, position: .zero, data: type)
    }

    func testRegisteredTypeIsDispatchedToItsBuilder() {
        var registry = CanvasNodeRegistry<String>()
        var built: [String] = []
        registry.register("prompt") { node, _ in
            built.append(node.id)
            return Text(node.data)
        }

        _ = registry.view(for: node("prompt"), context: CanvasNodeContext())
        XCTAssertEqual(built, ["prompt"])
    }

    func testUnregisteredTypeFallsBackWhenOneIsSet() {
        var registry = CanvasNodeRegistry<String>()
        var fellBack = false
        registry.register("prompt") { _, _ in Text("prompt") }
        registry.registerFallback { _, _ in
            fellBack = true
            return Text("fallback")
        }

        _ = registry.view(for: node("mystery"), context: CanvasNodeContext())
        XCTAssertTrue(fellBack, "an unknown type must not silently vanish")
    }

    func testRegisteredTypeIsPreferredOverTheFallback() {
        var registry = CanvasNodeRegistry<String>()
        var usedFallback = false
        registry.register("prompt") { _, _ in Text("specific") }
        registry.registerFallback { _, _ in
            usedFallback = true
            return Text("fallback")
        }

        _ = registry.view(for: node("prompt"), context: CanvasNodeContext())
        XCTAssertFalse(usedFallback)
    }

    func testReRegisteringATypeReplacesTheBuilder() {
        var registry = CanvasNodeRegistry<String>()
        var which = ""
        registry.register("n") { _, _ in which = "first"; return Text("a") }
        registry.register("n") { _, _ in which = "second"; return Text("b") }

        _ = registry.view(for: node("n"), context: CanvasNodeContext())
        XCTAssertEqual(which, "second")
    }

    func testContextReachesTheBuilder() {
        var registry = CanvasNodeRegistry<String>()
        var seen: CanvasNodeContext?
        registry.register("n") { _, context in
            seen = context
            return Text("x")
        }

        _ = registry.view(
            for: node("n"),
            context: CanvasNodeContext(isSelected: true, isDragging: true, zoom: 2))

        XCTAssertEqual(seen?.isSelected, true)
        XCTAssertEqual(seen?.isDragging, true)
        XCTAssertEqual(seen?.zoom, 2)
    }

    func testStandardHandlesAreOneTargetLeftAndOneSourceRight() {
        let handles = CanvasHandle.standard()
        XCTAssertEqual(handles.count, 2)
        XCTAssertEqual(handles.first { $0.kind == .target }?.position, .left)
        XCTAssertEqual(handles.first { $0.kind == .source }?.position, .right)
    }

    func testHandlesDefaultToTheEdgeMidpoint() {
        for handle in CanvasHandle.standard() {
            XCTAssertEqual(handle.offset, 0.5)
        }
    }

    func testNodeFrameIsEmptyUntilMeasured() {
        // Edges must not route against a node that hasn't laid out yet.
        XCTAssertEqual(node("n").frame.size, .zero)
    }
}
