#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import ShadcnUI

final class TextFieldKeyboardTests: XCTestCase {
    @MainActor
    func testLosingFocusDoesNotSubmit() throws {
        var submissions = 0
        let host = NSHostingView(rootView: ShadcnTextField("Search", text: .constant("query"), onSubmit: { submissions += 1 }))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 300, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        func findField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField { return field }
            return view.subviews.lazy.compactMap { findField(in: $0) }.first
        }
        let field = try XCTUnwrap(findField(in: host))
        XCTAssertFalse(try XCTUnwrap(field.cell).sendsActionOnEndEditing)
        XCTAssertTrue(window.makeFirstResponder(field))
        XCTAssertTrue(window.makeFirstResponder(nil))
        XCTAssertEqual(submissions, 0, "A focus transfer without Return must not submit")
        XCTAssertTrue(window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.insertText("new query", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        XCTAssertTrue(window.makeFirstResponder(nil))
        XCTAssertEqual(submissions, 0, "Ending editing after typing must not submit")
        XCTAssertTrue(window.makeFirstResponder(field))
        let returnEditor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        returnEditor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        XCTAssertEqual(submissions, 1, "Return must submit exactly once")
    }

    @MainActor
    private func makeCoordinator(
        onSubmit: (() -> Void)? = nil,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil
    ) -> ShadcnAppKitTextField.Coordinator {
        ShadcnAppKitTextField(
            placeholder: "Search", text: .constant("query"), isSecure: false,
            fontSize: 14, textColor: .primary, wantsFocus: false,
            onFocusChange: { _ in }, onSubmit: onSubmit,
            onMoveUp: onMoveUp, onMoveDown: onMoveDown
        ).makeCoordinator()
    }

    @MainActor
    func testArrowCommandsInvokeOnlyTheirCorrespondingCallback() {
        var up = 0
        var down = 0
        let coordinator = makeCoordinator(onMoveUp: { up += 1 }, onMoveDown: { down += 1 })
        let field = NSTextField()
        let editor = NSTextView()

        XCTAssertTrue(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        XCTAssertEqual(down, 1)
        XCTAssertEqual(up, 0)
        XCTAssertTrue(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))))
        XCTAssertEqual(up, 1)
    }

    @MainActor
    func testUnconfiguredAndEditingCommandsStayWithNativeTextField() {
        let coordinator = makeCoordinator(onMoveDown: {})
        let field = NSTextField()
        let editor = NSTextView()

        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))))
        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveLeft(_:))))
        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDownAndModifySelection(_:))))
        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
    }

    @MainActor
    func testMarkedTextKeepsArrowCommandsForInputMethod() {
        var moves = 0
        let coordinator = makeCoordinator(onMoveUp: { moves += 1 }, onMoveDown: { moves += 1 })
        let field = NSTextField()
        let editor = NSTextView()
        editor.setMarkedText("query", selectedRange: NSRange(location: 0, length: 5), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())

        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))))
        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        XCTAssertEqual(moves, 0)
    }

    @MainActor
    func testNativeCommitStillSubmitsOnce() {
        var submissions = 0
        let coordinator = makeCoordinator(onSubmit: { submissions += 1 }, onMoveDown: {})
        coordinator.commit(NSTextField(string: "query"))
        XCTAssertEqual(submissions, 1)
    }
}
#endif
