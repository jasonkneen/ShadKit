import AppKit
import SwiftUI
import XCTest
@testable import AIElementsUI

/// Drives a real `AIConversation` inside an `NSHostingView` and checks the
/// user can reach — and stay at — the true bottom after rows are appended.
@MainActor
final class ConversationScrollReachTests: XCTestCase {

    private final class Feed: ObservableObject {
        @Published var rows: [Row] = []
    }

    private struct Row: Identifiable {
        let id: Int
        let lines: Int
    }

    /// Like a markdown body: lays out short, then grows once it has rendered.
    private struct GrowingRow: View {
        let row: Row
        @State private var grown = false

        var body: some View {
            Text((0..<(grown ? row.lines : 1)).map { "row \(row.id) line \($0)" }
                .joined(separator: "\n"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .task {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    grown = true
                }
        }
    }

    private struct Host: View {
        @ObservedObject var feed: Feed

        var body: some View {
            AIConversation(streamToken: feed.rows.count) {
                ForEach(feed.rows) { row in
                    GrowingRow(row: row).id(row.id)
                }
            }
        }
    }

    private func spin(_ seconds: TimeInterval = 0.4) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        for child in view.subviews {
            if let found = scrollView(in: child) { return found }
        }
        return nil
    }

    func testAppendedVariableHeightRowsStayReachableAtTheBottom() throws {
        let feed = Feed()
        // Varied heights: lazy rows estimated from early rows mis-size later ones.
        feed.rows = (0..<60).map { Row(id: $0, lines: $0 % 7 == 0 ? 12 : 1) }

        let hosting = NSHostingView(rootView: Host(feed: feed))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.close() }
        spin()

        let scroll = try XCTUnwrap(scrollView(in: hosting))

        // Scroll up into history, then a burst of tall rows arrives off-screen.
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        spin()
        feed.rows += (60..<70).map { Row(id: $0, lines: 15) }
        spin()

        // The user wheels down to the bottom, as a trackpad/mouse would.
        for _ in 0..<80 {
            let cg = CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel,
                wheelCount: 1, wheel1: -60, wheel2: 0, wheel3: 0)!
            scroll.scrollWheel(with: NSEvent(cgEvent: cg)!)
            spin(0.02)
        }
        spin(0.8)

        let doc = try XCTUnwrap(scroll.documentView)
        let visible = scroll.contentView.bounds
        let distance = doc.isFlipped
            ? doc.frame.height - visible.maxY
            : visible.minY
        XCTAssertLessThanOrEqual(
            distance, 2,
            "conversation snapped away from the bottom (distance \(distance))")
    }
}
