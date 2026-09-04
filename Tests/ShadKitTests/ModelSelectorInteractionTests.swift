#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import AIElementsUI
import ShadcnUI

@MainActor
final class ModelSelectorInteractionTests: XCTestCase {
    private final class Selection {
        var model: AIModelOption?
        var presented = true
        init(_ model: AIModelOption? = nil) { self.model = model }
    }

    private struct Fixture {
        let window: NSWindow
        let host: NSHostingView<AnyView>
        let field: NSTextField
        let state: Selection
    }

    private func fixture(_ models: [AIModelOption], selected: AIModelOption? = nil,
                         listHeight: CGFloat = 260) async throws -> Fixture {
        let state = Selection(selected)
        let selector = AIModelSelector(
            models: models,
            selection: Binding(get: { state.model }, set: { state.model = $0 }),
            isPresented: Binding(get: { state.presented }, set: { state.presented = $0 }),
            width: 360, listHeight: listHeight)
            .shadcnTheme(.default)
        let host = NSHostingView(rootView: AnyView(selector))
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 360, height: listHeight + 40),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        try await settle()
        let field = try XCTUnwrap(descendant(NSTextField.self, in: host))
        return Fixture(window: window, host: host, field: field, state: state)
    }

    private func settle() async throws {
        try await Task.sleep(nanoseconds: 80_000_000)
    }

    private func descendant<T: NSView>(_ type: T.Type, in root: NSView) -> T? {
        if let view = root as? T { return view }
        return root.subviews.lazy.compactMap { self.descendant(type, in: $0) }.first
    }

    private func search(_ query: String, in fixture: Fixture) async throws {
        fixture.field.stringValue = query
        fixture.field.delegate?.controlTextDidChange?(Notification(
            name: NSControl.textDidChangeNotification, object: fixture.field))
        try await settle()
    }

    @discardableResult
    private func command(_ selector: Selector, in fixture: Fixture) async throws -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            let handled = fixture.field.sendAction(fixture.field.action, to: fixture.field.target)
            try await settle()
            return handled
        }
        let editor = fixture.field.currentEditor() as? NSTextView ?? NSTextView()
        let handled = fixture.field.delegate?.control?(fixture.field, textView: editor,
                                                       doCommandBy: selector) ?? false
        try await settle()
        return handled
    }

    func testHostedSearchHighlightsBestProviderFirstAndReturnSelectsIt() async throws {
        let models = [AIModelOption(id: "fuzzy", name: "Rapid Orion", provider: "A"),
                      AIModelOption(id: "exact", name: "Pro", provider: "Z")]
        let fixture = try await fixture(models)
        defer { fixture.window.close() }
        try await search("pro", in: fixture)
        let handled = try await command(#selector(NSResponder.insertNewline(_:)), in: fixture)
        XCTAssertTrue(handled)
        XCTAssertEqual(fixture.state.model?.id, "exact")
        XCTAssertFalse(fixture.state.presented)
    }

    func testHostedArrowNavigationClampsAndReturnSelectsHighlightedRow() async throws {
        let models = (0..<3).map { AIModelOption(id: "\($0)", name: "Model \($0)", provider: "Provider") }
        let fixture = try await fixture(models)
        defer { fixture.window.close() }
        try await command(#selector(NSResponder.moveUp(_:)), in: fixture)
        for _ in 0..<4 { try await command(#selector(NSResponder.moveDown(_:)), in: fixture) }
        try await command(#selector(NSResponder.moveUp(_:)), in: fixture)
        try await command(#selector(NSResponder.insertNewline(_:)), in: fixture)
        XCTAssertEqual(fixture.state.model?.id, "1")
        XCTAssertFalse(fixture.state.presented)
    }

    func testNoResultsReturnDoesNotSelectOrDismiss() async throws {
        let fixture = try await fixture([AIModelOption(id: "one", name: "One", provider: "Provider")])
        defer { fixture.window.close() }
        try await search("zzzz", in: fixture)
        try await command(#selector(NSResponder.moveDown(_:)), in: fixture)
        try await command(#selector(NSResponder.insertNewline(_:)), in: fixture)
        XCTAssertNil(fixture.state.model)
        XCTAssertTrue(fixture.state.presented)
    }

    func testSelectingRecentRowRetainsCanonicalIdentity() async throws {
        let model = AIModelOption(id: "model", name: "Model", provider: "Provider")
        let recent = AIModelOption(id: "recent:model", name: "Model", provider: "Recent", selectionID: "model")
        let other = AIModelOption(id: "other", name: "Other", provider: "Provider")
        let fixture = try await fixture([recent, model, other], selected: model)
        defer { fixture.window.close() }
        try await command(#selector(NSResponder.moveDown(_:)), in: fixture)
        try await command(#selector(NSResponder.moveDown(_:)), in: fixture)
        try await command(#selector(NSResponder.insertNewline(_:)), in: fixture)
        XCTAssertEqual(fixture.state.model?.id, recent.id)
        XCTAssertEqual(fixture.state.model?.selectionID, model.selectionID)
    }

    func testKeyboardHighlightScrollsOffscreenResultIntoView() async throws {
        let models = (0..<24).map { AIModelOption(id: "\($0)", name: "Model \($0)", provider: "Provider") }
        let fixture = try await fixture(models, listHeight: 120)
        defer { fixture.window.close() }
        let scroll = try XCTUnwrap(descendant(NSScrollView.self, in: fixture.host))
        let initialOffset = scroll.contentView.bounds.minY
        for _ in 0..<23 { try await command(#selector(NSResponder.moveDown(_:)), in: fixture) }
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, initialOffset)
        let document = try XCTUnwrap(scroll.documentView)
        XCTAssertGreaterThanOrEqual(scroll.contentView.bounds.maxY, document.bounds.maxY - 8,
                                    "Navigating to the final row must reveal the bottom of the model list")
        try await command(#selector(NSResponder.insertNewline(_:)), in: fixture)
        XCTAssertEqual(fixture.state.model?.id, "23")
    }
}
#endif
