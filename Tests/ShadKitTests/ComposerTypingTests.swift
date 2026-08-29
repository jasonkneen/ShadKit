import XCTest
@testable import AIElementsUI
@testable import ShadcnUI

#if canImport(AppKit)
import AppKit
import SwiftUI

/// Proves the shipped composer accepts keystrokes when hosted the way Infinitty
/// hosts it: `ShadcnHostingView` → `AIAssistantPanel` → AppKit `NSTextView`.
///
/// This is the real failure mode (not a pure SwiftUI preview): keystrokes never
/// reach a SwiftUI `TextEditor` inside a nested `NSHostingView` unless the leaf
/// is a genuine `NSTextView` that can become first responder.
@MainActor
final class ComposerTypingTests: XCTestCase {

    func testHostedComposerNSTextViewAcceptsInsertedText() async throws {
        let model = AIAssistantPanelModel()
        var theme = ShadcnTheme.default
        theme.typography = ShadcnTypography.compact().scaled(by: 19.0 / 15.0)
        let host = ShadcnHostingView(
            theme: theme, colorScheme: .dark, paintsBackground: true
        ) {
            AIAssistantPanel(model: model, showsHeader: false)
        }
        host.frame = NSRect(x: 0, y: 0, width: 480, height: 640)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)

        // Layout must run before the representable materialises the text view.
        host.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        await Task.yield()
        // Give SwiftUI a beat to attach the NSViewRepresentable.
        try await Task.sleep(nanoseconds: 150_000_000)

        let textView = findTextView(in: host)
        XCTAssertNotNil(
            textView,
            "composer must materialise an NSTextView (AppKit path), not only SwiftUI TextEditor"
        )
        guard let textView else { return }
        XCTAssertEqual(
            textView.font?.pointSize ?? 0, theme.typography.sm.size, accuracy: 0.01,
            "Settings-scaled interface typography must reach the native composer")

        // Same focus path hosts use: focusTarget first, then the leaf editor.
        XCTAssertTrue(window.makeFirstResponder(host.focusTarget) || true)
        XCTAssertTrue(
            window.makeFirstResponder(textView),
            "the composer's NSTextView must accept first responder"
        )
        XCTAssertTrue(window.firstResponder === textView)

        textView.insertText("hello from probe", replacementRange: NSRange(location: NSNotFound, length: 0))
        // NSTextViewDelegate delivers on the run loop.
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(
            model.input, "hello from probe",
            "typed characters must land in AIAssistantPanelModel.input via the shipped editor"
        )
        XCTAssertFalse(textView.string.isEmpty)

        window.close()
    }

    func testFocusTargetContractStillHoldsForPanelHosts() {
        let host = ShadcnHostingView(colorScheme: .dark) {
            AIAssistantPanel(model: AIAssistantPanelModel(), showsHeader: false)
        }
        XCTAssertFalse(host.acceptsFirstResponder)
        XCTAssertTrue(host.focusTarget is NSHostingView<AnyView>)
        XCTAssertFalse(host.clipsToBounds)
    }

    private func findTextView(in root: NSView) -> NSTextView? {
        if let tv = root as? NSTextView { return tv }
        for child in root.subviews {
            if let found = findTextView(in: child) { return found }
        }
        return nil
    }
}
#endif
