#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import AIElementsUI
@testable import ShadcnUI

@MainActor
final class ModelSelectorLayoutTests: XCTestCase {
    func testFlexibleSelectorFitsInsideDropdownChrome() throws {
        try assertPanelGeometry(outerWidth: 360, padding: 4)
    }

    func testFlexibleSelectorRespectsDifferentPanelPadding() throws {
        try assertPanelGeometry(outerWidth: 300, padding: 12)
    }

    func testStandaloneSelectorRetainsDefaultWidth() throws {
        let window = makeAnchorWindow()
        defer { window.close() }
        let controller = ShadcnFloatingPanelController()
        controller.anchorView = window.contentView
        defer { controller.close() }

        controller.show(edge: .top, alignment: .leading, onDismiss: {}) {
            AIModelSelector(
                models: Self.models,
                selection: .constant(nil),
                isPresented: .constant(true)
            )
            .fixedSize()
            .shadcnTheme()
        }

        let panel = try XCTUnwrap(window.childWindows?.first)
        XCTAssertEqual(panel.frame.width, 420, accuracy: 0.5)
    }

    private func assertPanelGeometry(outerWidth: CGFloat, padding: CGFloat) throws {
        let window = makeAnchorWindow()
        defer { window.close() }
        let controller = ShadcnFloatingPanelController()
        controller.anchorView = window.contentView
        defer { controller.close() }
        var selectorBounds: CGRect?
        var chromeBounds: CGRect?

        controller.show(
            edge: .top, alignment: .leading,
            contentWidth: outerWidth, onDismiss: {}
        ) {
            ShadcnPanel(padding: padding) {
                AIModelSelector(
                    models: Self.models,
                    selection: .constant(nil),
                    isPresented: .constant(true),
                    width: nil,
                    listHeight: 260
                )
                .background(GeometryProbe { selectorBounds = $0 })
            }
            .background(GeometryProbe { chromeBounds = $0 })
            .frame(width: outerWidth)
            .fixedSize()
            .coordinateSpace(name: "model-selector-window")
            .shadcnTheme()
        }

        let panel = try XCTUnwrap(window.childWindows?.first)
        let deadline = Date().addingTimeInterval(1)
        repeat {
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while (selectorBounds == nil || chromeBounds == nil) && Date() < deadline

        let selector = try XCTUnwrap(selectorBounds)
        let chrome = try XCTUnwrap(chromeBounds)
        XCTAssertEqual(panel.frame.width, outerWidth, accuracy: 0.5)
        XCTAssertEqual(chrome.minX, 0, accuracy: 0.5, "glass border must start inside the panel window")
        XCTAssertEqual(chrome.width, outerWidth, accuracy: 0.5, "glass border must not overflow the panel window")
        XCTAssertEqual(selector.minX, padding, accuracy: 0.5)
        XCTAssertEqual(selector.width, outerWidth - padding * 2, accuracy: 0.5)
        XCTAssertGreaterThan(selector.height, 260)
    }

    private func makeAnchorWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 500, height: 100),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.orderFront(nil)
        return window
    }

    private static let models = [
        AIModelOption(id: "model-a", name: "Model A", provider: "Provider"),
        AIModelOption(id: "model-b", name: String(repeating: "Long model name ", count: 8), provider: "Provider"),
    ]

    private struct GeometryProbe: View {
        let update: (CGRect) -> Void

        var body: some View {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { update(geometry.frame(in: .named("model-selector-window"))) }
                    .onChange(of: geometry.frame(in: .named("model-selector-window"))) { _, frame in
                        update(frame)
                    }
            }
        }
    }
}
#endif
