import XCTest
@testable import AIElementsUI
import ShadcnUI

@MainActor
final class AssistantPanelModelTests: XCTestCase {
    func testTerminalModeDefaultsOffAndRejectsUnavailableSelection() {
        let model = AIAssistantPanelModel()
        var changes: [Bool] = []
        model.onTerminalAccessChange = { changes.append($0) }

        XCTAssertFalse(model.terminalAvailable)
        XCTAssertFalse(model.terminalAccessEnabled)
        model.selectTerminalAccess(true)

        XCTAssertFalse(model.terminalAccessEnabled)
        XCTAssertEqual(changes, [])
    }

    func testAddSelectedAgentUsesExactVisibleModelAndEffort() {
        let model = AIAssistantPanelModel()
        model.agent = "claude"
        model.model = "Claude · Sonnet"
        model.effort = "High"
        var additions: [(String, String)] = []
        model.onAddAgent = { additions.append(($0, $1)) }

        model.addSelectedAgent()

        XCTAssertEqual(additions.count, 1)
        XCTAssertEqual(additions.first?.0, "Claude · Sonnet")
        XCTAssertEqual(additions.first?.1, "High")
    }

    func testRosterAndMessageAuthorAreStructuredState() {
        let model = AIAssistantPanelModel()
        model.roster = [AIAssistantRosterEntry(
            id: "claude|sonnet", name: "claude", detail: "Claude · Sonnet")]
        model.streamingAuthor = "Claude"
        let message = UIMessage(role: .assistant, text: "answer", author: "Claude")

        XCTAssertEqual(model.roster.first?.name, "claude")
        XCTAssertEqual(model.roster.first?.isEnabled, true)
        XCTAssertEqual(model.streamingAuthor, "Claude")
        XCTAssertEqual(message.author, "Claude")
        XCTAssertEqual(message.text, "answer")
    }

    func testRosterContextCarriesFullUsageForItsDetailPopover() {
        let usage = AIContextUsage(
            usedTokens: 188_290,
            maxTokens: 258_400,
            inputTokens: 188_290,
            outputTokens: 109,
            reasoningTokens: 7,
            cachedTokens: 186_112)
        let entry = AIAssistantRosterEntry(
            id: "auto", name: "Auto",
            detail: "Model: gpt-5.4 · Effort: High",
            contextUsage: usage)

        XCTAssertEqual(entry.contextUsage, usage)
        XCTAssertEqual(entry.contextFraction, usage.usedFraction)
    }

    func testRosterToggleAndSettingsOwnedFontSizeAreInteractiveState() {
        let model = AIAssistantPanelModel()
        var toggled: [String] = []
        model.onToggleAgent = { toggled.append($0) }
        model.toggleAgent("codex|sol")
        model.messageFontSize = 19

        XCTAssertEqual(toggled, ["codex|sol"])
        XCTAssertEqual(model.messageFontSize, 19)
    }

    func testRichPickerOptionsRetainProviderAndModelIcons() {
        let model = AIAssistantPanelModel()
        model.agentOptions = [ShadcnSelectOption(
            value: "Claude", label: "Claude", systemImage: "a.circle")]
        model.modelOptions = [ShadcnSelectOption(
            value: "claude-sonnet-5", label: "Sonnet 5", systemImage: "a.circle")]

        XCTAssertEqual(model.agentOptions.first?.systemImage, "a.circle")
        XCTAssertEqual(model.modelOptions.first?.systemImage, "a.circle")
    }

    func testEffortSignalUsesOneVariableCellularGlyphFromNoneToAllBars() {
        XCTAssertEqual(ShadcnIcon.cellularBars, "cellularbars")
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "None"), 0)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "Minimal"), 0.15)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "Low"), 0.33)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "Auto"), 0.5)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "Medium"), 0.6)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "High"), 0.8)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "Xhigh"), 0.9)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "Maximum"), 1)
        XCTAssertEqual(AIAssistantPanelModel.effortSignalValue(for: "Ultra"), 1)
    }

    func testCompactPromptCanReserveItsTopRightModeControls() {
        var style = AIPromptInputStyle.compact
        XCTAssertEqual(style.textFieldTrailingAccessoryWidth, 0)

        style.textFieldTrailingAccessoryWidth = 64

        XCTAssertEqual(style.textFieldTrailingAccessoryWidth, 64)
        XCTAssertEqual(style.minTextHeight, 34)
    }

    func testTerminalModeSelectionInvokesSemanticCallbackWhenAvailable() {
        let model = AIAssistantPanelModel()
        var changes: [Bool] = []
        model.onTerminalAccessChange = { changes.append($0) }
        model.terminalAvailable = true

        model.selectTerminalAccess(true)
        XCTAssertTrue(model.terminalAccessEnabled)
        model.selectTerminalAccess(false)

        XCTAssertFalse(model.terminalAccessEnabled)
        XCTAssertEqual(changes, [true, false])

        model.selectTerminalAccess(true)
        model.terminalAvailable = false
        XCTAssertFalse(model.terminalAccessEnabled)
    }
}
