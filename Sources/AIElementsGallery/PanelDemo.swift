import AIElementsUI
import ShadcnUI
import SwiftUI

/// The assistant panel at the size it runs in Infinitty's sidebar, so layout
/// problems show up here rather than after installing.
struct PanelDemo: View {
    @StateObject private var idle = PanelDemo.makeModel(populated: false)
    @StateObject private var live = PanelDemo.makeModel(populated: true)
    @StateObject private var topBarModel = PanelDemo.makeTopBarModel()

    @State private var inspectorOpen = true
    @State private var inspectorWidth: CGFloat = 280
    @State private var inspectorTab: AIInspectorTab = .session
    @State private var commitMessage = ""
    @State private var inspectorBranch = "main"
    @State private var rosterEntries: [AIAssistantRosterEntry] = [
        AIAssistantRosterEntry(id: "claude", name: "claude", detail: "Claude Opus 5", isWorking: true),
        AIAssistantRosterEntry(id: "researcher", name: "researcher", detail: "Sub-agent", contextFraction: 0.4),
        AIAssistantRosterEntry(id: "grok", name: "grok", detail: "Grok 4", hasMissingKey: true),
    ]

    var body: some View {
        GalleryHeading(
            title: "Assistant panel",
            subtitle: "The whole surface — transcript, queue and composer — at sidebar width."
        )

        HStack(alignment: .top, spacing: Space.x6) {
            GalleryBlock("Empty") {
                AIAssistantPanel(model: idle)
                    .frame(width: 340, height: 520)
                    .shadcnBorderedBox()
            }
            GalleryBlock("With a conversation") {
                AIAssistantPanel(model: live)
                    .frame(width: 380, height: 520)
                    .shadcnBorderedBox()
            }
            GalleryBlock("Deck slots") {
                AIAssistantPanel(
                    model: live,
                    deckSlots: AIAssistantPanelDeckSlots(
                        aboveTranscript: {
                            AnyView(
                                ShadcnBadge("Session restored", variant: .outline)
                                    .padding(.horizontal, Space.x3)
                                    .padding(.top, Space.x2)
                            )
                        },
                        aboveComposer: {
                            AnyView(
                                Text("2 files changed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, Space.x3)
                            )
                        },
                        messageAccessory: { message in
                            AnyView(
                                AIMessageAction(systemImage: ShadcnIcon.gitBranch, tooltip: "Fork") {}
                            )
                        }
                    )
                )
                .frame(width: 380, height: 520)
                .shadcnBorderedBox()
            }
        }

        GalleryBlock("Top bar — thread select keeps its width at narrow panes (U17)") {
            VStack(alignment: .leading, spacing: Space.x3) {
                ForEach([320, 480], id: \.self) { width in
                    VStack(alignment: .leading, spacing: Space.x1) {
                        Text("\(width)pt")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        AIAssistantPanelTopBar(
                            model: topBarModel,
                            chrome: AIAssistantPanelChrome(topBarPlacement: .panel)
                        ) {
                            ShadcnBadge("● connected", variant: .outline)
                        }
                        .frame(width: CGFloat(width))
                        .shadcnBorderedBox()
                    }
                }
            }
        }

        GalleryBlock("Roster rail — reorder, working, menu") {
            AIAssistantRosterRail(
                entries: rosterEntries,
                onToggle: { id in
                    guard let index = rosterEntries.firstIndex(where: { $0.id == id }) else { return }
                    rosterEntries[index] = AIAssistantRosterEntry(
                        id: rosterEntries[index].id,
                        name: rosterEntries[index].name,
                        detail: rosterEntries[index].detail,
                        isEnabled: !rosterEntries[index].isEnabled,
                        contextFraction: rosterEntries[index].contextFraction,
                        isWorking: rosterEntries[index].isWorking,
                        hasMissingKey: rosterEntries[index].hasMissingKey
                    )
                },
                onReorder: { order in
                    rosterEntries.sort { a, b in
                        (order.firstIndex(of: a.id) ?? 0) < (order.firstIndex(of: b.id) ?? 0)
                    }
                },
                onEdit: { _ in },
                onRemove: { id in rosterEntries.removeAll { $0.id == id } }
            )
            .shadcnBorderedBox()
        }

        GalleryBlock("Inspector — Session / Usage / Files") {
            // Docked the way it's meant to be used: `AIInspector` now owns
            // its own leading-edge drag handle (0.3.1) and writes `width`
            // directly, and collapse-to-icon-rail is its own `isOpen`
            // toggle. Nesting it in a `ShadcnResizeSplit` here still works
            // — both write the same binding — but is no longer required
            // just to get a working handle.
            ShadcnResizeSplit(width: $inspectorWidth, defaultWidth: 280, minWidth: 220, maxWidth: 420, edge: .trailing) {
                AIInspector(
                    isOpen: $inspectorOpen,
                    width: $inspectorWidth,
                    tab: $inspectorTab,
                    commitMessage: $commitMessage,
                    branch: $inspectorBranch,
                    session: AIInspectorSession(
                        location: "/Users/dev/ShadKit",
                        sessionReference: "sess_9f2a",
                        seatCount: rosterEntries.count,
                        isLive: true
                    ),
                    usage: AIInspectorUsage(
                        contextEstimate: 0.42,
                        toolCalls: 6,
                        inputTokens: 12_400,
                        outputTokens: 3_100,
                        cachePercent: 0.6,
                        costText: "$0.18"
                    ),
                    todos: [
                        AITodoItem(title: "Wire the inspector into the panel", status: .inProgress),
                        AITodoItem(title: "Port the roster row", status: .completed),
                    ],
                    events: [AIActivityEvent(toolName: "search_codebase", duration: 0.8)],
                    changes: [AIActivityFileChange(path: "AssistantInspector.swift", additions: 210, deletions: 0)],
                    repo: AIInspectorRepo(folder: "ShadKit", branch: "main", ahead: 1, behind: 0)
                )
            } content: {
                VStack(alignment: .leading, spacing: Space.x3) {
                    AIMessage(.user) {
                        Text("Which file does the OKLCH conversion live in?")
                    }
                    AIMessage(.assistant) {
                        Text("It's in ShadcnPalette+OKLCH.swift — I'll pull up the diff in the Files tab.")
                    }
                    Spacer(minLength: 0)
                }
                .padding(Space.x4)
            }
            .frame(height: 420)
            .shadcnBorderedBox()
        }
    }

    static func makeTopBarModel() -> AIAssistantPanelModel {
        let model = AIAssistantPanelModel()
        model.threads = [
            ShadcnSelectOption(
                value: "t1", label: "The complete migration plan for the OKLCH token pipeline"),
            ShadcnSelectOption(value: "t2", label: "Fix flaky test"),
        ]
        model.activeThreadId = "t1"
        return model
    }

    static func makeModel(populated: Bool) -> AIAssistantPanelModel {
        let model = AIAssistantPanelModel()
        model.models = [
            (value: "opus", label: "Claude Opus 5"),
            (value: "sonnet", label: "Claude Sonnet 5"),
        ]
        model.efforts = [
            (value: "auto", label: "Auto"),
            (value: "high", label: "High"),
        ]
        model.model = "opus"
        model.effort = "auto"
        guard populated else { return model }

        model.messages = [
            UIMessage(role: .user, text: "Which file does the OKLCH conversion live in?"),
            UIMessage(
                role: .assistant,
                parts: [
                    .reasoning("Searching for the conversion, then confirming the matrices.", duration: 3),
                    .tool(
                        UIToolPart(
                            id: "t1", type: "tool-search_codebase", state: .outputAvailable,
                            input: "{\n  \"query\": \"OKLCH\"\n}",
                            output: "{\n  \"file\": \"OKLCH.swift\",\n  \"matches\": 3\n}")),
                    .text(
                        """
                        It's in `Sources/ShadcnUI/Theme/OKLCH.swift`.

                        ```swift
                        let background = OKLCH(0.145, 0, 0)
                        ```
                        """),
                ]),
        ]
        model.streamingText = "Want me to walk through the matrices"
        model.isThinking = true
        model.queued = ["Then check the dark palette"]
        return model
    }
}
