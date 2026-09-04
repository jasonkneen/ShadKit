import XCTest
@testable import ShadcnUI

/// Guards `ShadcnCommandModel.filter`, the pure substring rule behind
/// `ShadcnCommand`'s search field.
final class CommandModelTests: XCTestCase {

    private var groups: [ShadcnCommandGroup] {
        [
            ShadcnCommandGroup(id: "chats", title: "Chats", items: [
                ShadcnCommandItem(id: "c1", title: "Refactor auth flow", subtitle: "2 hours ago"),
                ShadcnCommandItem(id: "c2", title: "Fix flaky test", subtitle: "yesterday"),
            ]),
            ShadcnCommandGroup(id: "actions", title: "Actions", items: [
                ShadcnCommandItem(id: "a1", title: "New chat", shortcut: "\u{2318}N"),
                ShadcnCommandItem(id: "a2", title: "Toggle sidebar", shortcut: "\u{2318}B"),
            ]),
        ]
    }

    func testEmptyQueryReturnsAllGroupsUnchanged() {
        let result = ShadcnCommandModel.filter(groups, query: "")
        XCTAssertEqual(result.map(\.id), ["chats", "actions"])
        XCTAssertEqual(result[0].items.count, 2)
        XCTAssertEqual(result[1].items.count, 2)
    }

    func testMatchIsCaseInsensitiveSubstring() {
        let result = ShadcnCommandModel.filter(groups, query: "REFACTOR")
        XCTAssertEqual(result.map(\.id), ["chats"])
        XCTAssertEqual(result[0].items.map(\.id), ["c1"])
    }

    func testMatchesAgainstSubtitleToo() {
        let result = ShadcnCommandModel.filter(groups, query: "yesterday")
        XCTAssertEqual(result.map(\.id), ["chats"])
        XCTAssertEqual(result[0].items.map(\.id), ["c2"])
    }

    func testGroupsWithNoMatchingItemsAreDropped() {
        let result = ShadcnCommandModel.filter(groups, query: "sidebar")
        XCTAssertEqual(result.map(\.id), ["actions"])
        XCTAssertEqual(result[0].items.map(\.id), ["a2"])
    }

    func testNoMatchesReturnsEmptyArray() {
        let result = ShadcnCommandModel.filter(groups, query: "nonexistent-xyz")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - ShadcnCommandKeyboardSelection (U16)

    private var flatItems: [ShadcnCommandItem] {
        groups.flatMap(\.items)
    }

    func testSyncHighlightsTheFirstItemWhenNothingWasHighlighted() {
        let selection = ShadcnCommandKeyboardSelection()
        selection.sync(flatItems)
        XCTAssertEqual(selection.highlighted, "c1")
    }

    func testSyncKeepsAnExistingHighlightIfStillPresent() {
        let selection = ShadcnCommandKeyboardSelection()
        selection.sync(flatItems)
        selection.moveSelection(by: 1)
        XCTAssertEqual(selection.highlighted, "c2")
        selection.sync(flatItems)
        XCTAssertEqual(selection.highlighted, "c2")
    }

    func testMoveSelectionClampsAtBothEnds() {
        let selection = ShadcnCommandKeyboardSelection()
        selection.sync(flatItems)
        selection.moveSelection(by: -5)
        XCTAssertEqual(selection.highlighted, "c1")
        selection.moveSelection(by: 5)
        XCTAssertEqual(selection.highlighted, "a2")
    }

    func testActivateSelectionInvokesOnSelectWithTheHighlightedItem() {
        let selection = ShadcnCommandKeyboardSelection()
        selection.sync(flatItems)
        selection.moveSelection(by: 1)
        var selected: ShadcnCommandItem?
        selection.activateSelection { selected = $0 }
        XCTAssertEqual(selected?.id, "c2")
    }

    func testActivateSelectionDoesNothingWithNoItems() {
        let selection = ShadcnCommandKeyboardSelection()
        var called = false
        selection.activateSelection { _ in called = true }
        XCTAssertFalse(called)
    }
}
