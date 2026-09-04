#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import AIElementsUI
@testable import ShadcnUI

@MainActor
final class ModelSelectorPresentationTests: XCTestCase {
    @MainActor
    private final class State: ObservableObject {
        @Published var selection: AIModelOption?
        @Published var presented = true
        var selectedIDs: [String] = []
        var dismissed = false

        var selectionBinding: Binding<AIModelOption?> {
            Binding(get: { self.selection }, set: {
                self.selection = $0
                if let id = $0?.id { self.selectedIDs.append(id) }
            })
        }
        var presentedBinding: Binding<Bool> {
            Binding(get: { self.presented }, set: { self.presented = $0 })
        }
    }

    func testMakingFloatingSearchPanelKeyDoesNotSelectBeforeReturn() async throws {
        let state = State()
        let parent = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 500),
            styleMask: [.titled], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        let anchor = NSView(frame: NSRect(x: 20, y: 20, width: 100, height: 30))
        parent.contentView?.addSubview(anchor)
        parent.makeKeyAndOrderFront(nil)
        let controller = ShadcnFloatingPanelController()
        controller.anchorView = anchor
        defer { controller.close(); parent.close() }

        controller.show(
            edge: .top, alignment: .leading, contentWidth: 360, makesKey: true,
            onDismiss: { state.dismissed = true; state.presented = false }
        ) {
            ShadcnPanel {
                AIModelSelector(models: Self.models, selection: state.selectionBinding,
                                isPresented: state.presentedBinding, width: nil, listHeight: 260)
            }
            .frame(width: 360).fixedSize().shadcnTheme()
        }
        let panel = try XCTUnwrap(parent.childWindows?.first)
        try await settle(panel)
        XCTAssertTrue(controller.isShown)
        XCTAssertTrue(state.presented)
        XCTAssertFalse(state.dismissed)
        XCTAssertEqual(state.selectedIDs, [], "Opening/layout/autofocus cannot select the first row")

        let host = try XCTUnwrap(panel.contentView)
        let field = try XCTUnwrap(findField(in: host))
        XCTAssertTrue(panel.makeFirstResponder(field))
        XCTAssertTrue(panel.makeFirstResponder(host))
        try await settle(panel)
        XCTAssertEqual(state.selectedIDs, [], "Moving focus back to the host cannot select")
        XCTAssertTrue(state.presented)

        XCTAssertTrue(panel.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        try await settle(panel)
        XCTAssertEqual(state.selectedIDs, ["first"])
        XCTAssertFalse(state.presented)
    }

    func testDropdownBindingPresentationDoesNotSelectDuringAutofocus() async throws {
        let state = State()
        state.presented = false
        let host = NSHostingView(rootView: DropdownFixture(state: state).shadcnTheme())
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 500),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await settle(window)
        state.presented = true
        try await settle(window)
        XCTAssertTrue(state.presented)
        XCTAssertEqual(state.selectedIDs, [])
        let panel = try XCTUnwrap(window.childWindows?.first)
        XCTAssertTrue(panel.isVisible)
        let field = try XCTUnwrap(findField(in: try XCTUnwrap(panel.contentView)))
        XCTAssertTrue(panel.makeFirstResponder(field))
        try await settle(panel)
        XCTAssertEqual(state.selectedIDs, [])
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        try await settle(window)
        XCTAssertEqual(state.selectedIDs, ["first"])
        XCTAssertFalse(state.presented)
        XCTAssertTrue(window.childWindows?.isEmpty ?? true)
    }

    private struct DropdownFixture: View {
        @ObservedObject var state: State
        var body: some View {
            ShadcnDropdownMenu(isPresented: state.presentedBinding, minWidth: 360, edge: .top) {
                Button("Model") { state.presented.toggle() }
            } content: {
                AIModelSelector(models: ModelSelectorPresentationTests.models,
                                selection: state.selectionBinding,
                                isPresented: state.presentedBinding, width: nil, listHeight: 260)
            }
        }
    }

    private func settle(_ window: NSWindow) async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        try await Task.sleep(nanoseconds: 250_000_000)
    }

    private func findField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }
        return view.subviews.lazy.compactMap { self.findField(in: $0) }.first
    }

    private static let models = [
        AIModelOption(id: "first", name: "First model", provider: "A"),
        AIModelOption(id: "second", name: "Second model", provider: "B"),
    ]
}
#endif
