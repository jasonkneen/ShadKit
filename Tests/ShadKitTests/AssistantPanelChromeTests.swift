import SwiftUI
import XCTest
@testable import AIElementsUI

#if canImport(AppKit)
import AppKit

private struct TopBarAccessoryWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private let topBarAccessoryProbeText =
    "RESPONDING · 512/16.4K ctx · USD 0.01 · 2 queued"

private struct TopBarAccessoryProbe: View {
    let onWidth: (CGFloat) -> Void

    var body: some View {
        Text(topBarAccessoryProbeText)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .allowsTightening(true)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TopBarAccessoryWidthPreferenceKey.self,
                        value: proxy.size.width)
                }
            }
            .onPreferenceChange(TopBarAccessoryWidthPreferenceKey.self) {
                onWidth($0)
            }
    }
}
#endif

@MainActor
final class AssistantPanelChromeTests: XCTestCase {

    // MARK: - AIAssistantPanelThreadAccessoryWidths (U17 follow-up)

    func testBothSidesGetTheirIdealWidthWhenTheyFitTogether() {
        // Team's reported case: a 30pt accessory next to a 200pt title in a
        // 480pt bar — the title must not be crushed toward its minimum just
        // because a flexible sibling exists.
        let result = AIAssistantPanelThreadAccessoryWidths.split(
            threadIdeal: 200, accessoryIdeal: 30, available: 480, spacing: 8)
        XCTAssertGreaterThanOrEqual(result.thread, 190)
        XCTAssertEqual(result.thread, 200)
    }

    func testSurplusAfterBothIdealsGoesToTheAccessory() {
        let result = AIAssistantPanelThreadAccessoryWidths.split(
            threadIdeal: 100, accessoryIdeal: 40, available: 300, spacing: 10)
        XCTAssertEqual(result.thread, 100)
        XCTAssertEqual(result.accessory, 190)
    }

    func testAccessoryKeepsAtLeast65PercentOfItsIdealWhenBothAreLong() {
        // Mirrors AssistantPanelChromeTests' AppKit-level pin: a long title
        // and the real run-status accessory in a 320pt bar.
        let result = AIAssistantPanelThreadAccessoryWidths.split(
            threadIdeal: 240, accessoryIdeal: 220, available: 320, spacing: 8)
        XCTAssertGreaterThanOrEqual(result.accessory, 220 * 0.65)
    }

    func testThreadTakesWhateverTheAccessorysGuaranteedShareLeavesBehind() {
        let result = AIAssistantPanelThreadAccessoryWidths.split(
            threadIdeal: 240, accessoryIdeal: 220, available: 320, spacing: 8)
        XCTAssertEqual(result.thread + result.accessory, 320 - 8, accuracy: 0.01)
    }

    func testZeroOrNegativeAvailableWidthNeverGoesNegative() {
        let result = AIAssistantPanelThreadAccessoryWidths.split(
            threadIdeal: 100, accessoryIdeal: 50, available: 4, spacing: 8)
        XCTAssertEqual(result.thread, 0)
        XCTAssertEqual(result.accessory, 0)
    }

    func testChromeDefaultsPreserveLegacyPanelPresentation() {
        let chrome = AIAssistantPanelChrome()

        XCTAssertTrue(chrome.showsHeader)
        XCTAssertFalse(chrome.hasExternalNewChatAction)
        XCTAssertEqual(chrome.topBarPlacement, .panel)
        XCTAssertEqual(chrome.rosterPresentation, .row)
        XCTAssertEqual(chrome.density, .standard)
    }

    func testLegacyInitializerMapsOnlyShowsHeaderIntoStandardPanelChrome() {
        let model = AIAssistantPanelModel()

        let visibleHeader = AIAssistantPanel(model: model)
        let hiddenHeader = AIAssistantPanel(model: model, showsHeader: false)

        XCTAssertEqual(
            visibleHeader.chrome,
            AIAssistantPanelChrome(
                showsHeader: true,
                hasExternalNewChatAction: false,
                topBarPlacement: .panel,
                rosterPresentation: .row,
                density: .standard
            )
        )
        XCTAssertEqual(
            hiddenHeader.chrome,
            AIAssistantPanelChrome(
                showsHeader: false,
                hasExternalNewChatAction: false,
                topBarPlacement: .panel,
                rosterPresentation: .row,
                density: .standard
            )
        )
    }

    func testNewChatOwnershipHasExactlyOneInternalOwner() {
        XCTAssertEqual(
            AIAssistantPanelChrome(showsHeader: true).newChatOwner,
            .header
        )
        XCTAssertEqual(
            AIAssistantPanelChrome(showsHeader: false).newChatOwner,
            .topBar
        )
        XCTAssertEqual(
            AIAssistantPanelChrome(
                showsHeader: true,
                hasExternalNewChatAction: true
            ).newChatOwner,
            .external
        )
        XCTAssertEqual(
            AIAssistantPanelChrome(
                showsHeader: false,
                hasExternalNewChatAction: true
            ).newChatOwner,
            .external
        )
    }

    func testExternalPlacementSuppressesPanelTopBarAndSeparator() {
        let chrome = AIAssistantPanelChrome(topBarPlacement: .external)
        let panel = AIAssistantPanel(model: AIAssistantPanelModel(), chrome: chrome)

        XCTAssertFalse(panel.rendersTopBar)
        XCTAssertFalse(panel.rendersTopBarSeparator)
    }

    func testDensitySelectsTheSharedConversationAndMessageStyles() {
        let model = AIAssistantPanelModel()
        let standard = AIAssistantPanel(
            model: model,
            chrome: AIAssistantPanelChrome(density: .standard)
        )
        let compact = AIAssistantPanel(
            model: model,
            chrome: AIAssistantPanelChrome(density: .compact)
        )

        XCTAssertEqual(standard.conversationStyle, .standard)
        XCTAssertEqual(standard.messageStyle, .standard)
        XCTAssertEqual(compact.conversationStyle, .compact)
        XCTAssertEqual(compact.messageStyle, .compact)
    }

    func testRosterPresentationResolvesRowAndCompactControls() {
        let row = AIAssistantPanelChrome(rosterPresentation: .row)
        XCTAssertTrue(row.rendersRosterRow(rosterCount: 1))
        XCTAssertTrue(row.rendersRosterRow(rosterCount: 3))
        XCTAssertEqual(row.topBarRosterControl(rosterCount: 1), .none)

        let menu = AIAssistantPanelChrome(rosterPresentation: .menu)
        XCTAssertFalse(menu.rendersRosterRow(rosterCount: 1))
        XCTAssertEqual(menu.topBarRosterControl(rosterCount: 0), .none)
        XCTAssertEqual(menu.topBarRosterControl(rosterCount: 1), .single)
        XCTAssertEqual(menu.topBarRosterControl(rosterCount: 3), .menu)
    }

    func testDisabledSoleAgentStillResolvesToADirectToggle() {
        let model = AIAssistantPanelModel()
        model.roster = [
            AIAssistantRosterEntry(
                id: "codex",
                name: "Codex",
                detail: "GPT-5.4",
                isEnabled: false
            )
        ]
        let chrome = AIAssistantPanelChrome(rosterPresentation: .menu)

        XCTAssertEqual(
            chrome.topBarRosterControl(rosterCount: model.roster.count),
            .single
        )
    }

    func testSelectThreadAcceptsOnlyKnownDifferentThreadAndCallsBackOnce() {
        let model = AIAssistantPanelModel()
        model.threads = [
            .init(value: "first", label: "First"),
            .init(value: "second", label: "Second"),
        ]
        model.activeThreadId = "first"
        var selected: [String] = []
        model.onSelectThread = { selected.append($0) }

        model.selectThread("missing")
        model.selectThread("first")
        model.selectThread("second")
        model.selectThread("second")

        XCTAssertEqual(model.activeThreadId, "second")
        XCTAssertEqual(selected, ["second"])
    }

    func testConversationIdentityChangesAcrossThreadsWhenStreamTokenCollides() {
        let model = AIAssistantPanelModel()
        model.messages = [
            UIMessage(id: "same-message", role: .assistant, text: "Same content")
        ]
        let panel = AIAssistantPanel(model: model)
        let streamToken = model.streamToken

        XCTAssertEqual(panel.conversationIdentity, .unscoped)

        model.activeThreadId = "first"
        let firstIdentity = panel.conversationIdentity
        XCTAssertEqual(firstIdentity, .thread("first"))
        XCTAssertEqual(model.streamToken, streamToken)

        model.activeThreadId = "second"
        let secondIdentity = panel.conversationIdentity
        XCTAssertEqual(secondIdentity, .thread("second"))
        XCTAssertNotEqual(secondIdentity, firstIdentity)
        XCTAssertEqual(model.streamToken, streamToken)

        model.activeThreadId = nil
        XCTAssertEqual(panel.conversationIdentity, .unscoped)
        XCTAssertNotEqual(panel.conversationIdentity, secondIdentity)
        XCTAssertEqual(model.streamToken, streamToken)
    }

    func testStartNewChatUsesTheSingleModelCallbackPath() {
        let model = AIAssistantPanelModel()
        var starts = 0
        model.onNewChat = { starts += 1 }

        model.startNewChat()

        XCTAssertEqual(starts, 1)
    }

    func testPublicTopBarInitializersSupportEmptyAndCustomAccessories() {
        let model = AIAssistantPanelModel()
        let chrome = AIAssistantPanelChrome(
            showsHeader: false,
            rosterPresentation: .menu,
            density: .compact
        )

        _ = AIAssistantPanelTopBar(model: model, chrome: chrome)
        _ = AIAssistantPanelTopBar(model: model, chrome: chrome) {
            Text("Accessory")
        }
    }

    #if canImport(AppKit)
    func testCompleteCompactPanelFitsA320By500HostAndMaterializesComposer() {
        let model = AIAssistantPanelModel()
        model.threads = [
            .init(
                value: "one",
                label: "A deliberately long thread title that must truncate"
            ),
            .init(value: "two", label: "Second thread"),
        ]
        model.activeThreadId = "one"
        model.roster = [
            .init(
                id: "claude-sonnet", name: "Claude", detail: "Sonnet 5",
                isEnabled: true
            ),
            .init(
                id: "codex-gpt", name: "Codex", detail: "GPT-5.4",
                isEnabled: false
            ),
        ]
        model.messages = [
            UIMessage(
                id: "question", role: .user,
                text: "Can you explain the current workspace state?"
            ),
            UIMessage(
                id: "answer", role: .assistant,
                text: "The workspace is ready for a focused implementation pass.",
                author: "Claude"
            ),
        ]
        model.agentOptions = [
            .init(value: "claude", label: "Claude", systemImage: "c.circle"),
            .init(value: "codex", label: "Codex", systemImage: "chevron.left.forwardslash.chevron.right"),
        ]
        model.agent = "claude"
        model.modelOptions = [
            .init(value: "sonnet-5", label: "Sonnet 5"),
            .init(value: "gpt-5.4", label: "GPT-5.4"),
        ]
        model.model = "sonnet-5"
        model.effortOptions = [
            .init(value: "medium", label: "Medium"),
            .init(value: "high", label: "High"),
        ]
        model.effort = "high"
        model.hasFiles = true
        model.terminalAvailable = true
        model.terminalAccessEnabled = true
        let chrome = AIAssistantPanelChrome(
            showsHeader: false,
            rosterPresentation: .menu,
            density: .compact
        )
        var accessoryWidth: CGFloat = 0
        let topBarHost = NSHostingView(
            rootView: AIAssistantPanelTopBar(model: model, chrome: chrome) {
                TopBarAccessoryProbe { accessoryWidth = $0 }
            }
        )

        topBarHost.frame = NSRect(x: 0, y: 0, width: 320, height: 44)
        let topBarWindow = NSWindow(
            contentRect: topBarHost.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        topBarWindow.isReleasedWhenClosed = false
        topBarWindow.contentView = topBarHost
        topBarWindow.orderFront(nil)
        defer { topBarWindow.close() }

        let accessoryMeasured = pollRunLoop(timeout: 1.0) {
            topBarHost.layoutSubtreeIfNeeded()
            topBarWindow.layoutIfNeeded()
            return accessoryWidth > 0
        }

        XCTAssertTrue(accessoryMeasured)
        XCTAssertEqual(topBarHost.frame.width, 320)
        let minimumReadableAccessoryWidth =
            (topBarAccessoryProbeText as NSString).size(withAttributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            ]).width * 0.65
        XCTAssertGreaterThanOrEqual(
            accessoryWidth, minimumReadableAccessoryWidth,
            "the status must fit its complete text at the allowed scale")
        XCTAssertGreaterThan(topBarHost.fittingSize.height, 0)

        let panelHost = NSHostingView(
            rootView: AIAssistantPanel(model: model, chrome: chrome)
        )
        panelHost.frame = NSRect(x: 0, y: 0, width: 320, height: 500)
        let window = NSWindow(
            contentRect: panelHost.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = panelHost
        window.orderFront(nil)
        defer { window.close() }

        let textViewMaterialized = pollRunLoop(timeout: 1.0) {
            panelHost.layoutSubtreeIfNeeded()
            window.layoutIfNeeded()
            return self.findTextView(in: panelHost) != nil
        }

        XCTAssertTrue(textViewMaterialized, "the complete panel must materialize its native composer")
        XCTAssertEqual(panelHost.frame.size.width, 320, accuracy: 0.5)
        XCTAssertEqual(panelHost.frame.size.height, 500, accuracy: 0.5)

        guard let textView = findTextView(in: panelHost) else { return }
        let composerRect = textView.convert(textView.bounds, to: panelHost)

        XCTAssertGreaterThan(composerRect.width, 0)
        XCTAssertGreaterThan(composerRect.height, 0)
        XCTAssertTrue(
            panelHost.bounds.insetBy(dx: -0.5, dy: -0.5).contains(composerRect),
            "native composer \(composerRect) must remain inside panel bounds \(panelHost.bounds)"
        )
    }

    private func pollRunLoop(
        timeout: TimeInterval,
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.01)))
        } while Date() < deadline
        return condition()
    }

    private func findTextView(in root: NSView) -> NSTextView? {
        if let textView = root as? NSTextView { return textView }
        for child in root.subviews {
            if let textView = findTextView(in: child) { return textView }
        }
        return nil
    }
    #endif
}
