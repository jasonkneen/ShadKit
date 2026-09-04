import AIElementsUI
import ShadcnUI
import SwiftUI

// MARK: - Provider composer templates

struct TemplatesDemo: View {
    @State private var chatgptText = ""
    @State private var claudeText = ""
    @State private var grokText = ""
    @State private var claudeModel: String? = "opus"
    @State private var grokModel: String? = "grok-4"

    var body: some View {
        GalleryHeading(
            title: "Composer templates",
            subtitle: "The ChatGPT, Claude and Grok input templates, ported 1:1."
        )

        GalleryBlock("ChatGPT") {
            AIChatGPTComposer(
                text: $chatgptText,
                suggestions: ["Brainstorm names", "Summarise a doc", "Write code"],
                onSubmit: {}
            )
            .frame(maxWidth: 680)
            .zIndex(3)
        }

        GalleryBlock("Claude") {
            AIClaudeComposer(
                text: $claudeText,
                model: $claudeModel,
                models: [
                    ("opus", "Claude Opus 5"),
                    ("sonnet", "Claude Sonnet 5"),
                    ("haiku", "Claude Haiku 4.5"),
                ],
                onSubmit: {}
            )
            .frame(maxWidth: 680)
            .zIndex(2)
        }

        GalleryBlock("Grok") {
            AIGrokComposer(
                text: $grokText,
                model: $grokModel,
                models: [("grok-4", "Grok 4"), ("grok-3", "Grok 3")],
                onSubmit: {}
            )
            .frame(maxWidth: 680)
            .zIndex(1)
        }
    }
}

// MARK: - Live chatbot block

struct ChatbotDemo: View {
    @StateObject private var chat = AIChat(transport: GalleryTransport())

    @State private var roster: [AIAssistantRosterEntry] = [
        AIAssistantRosterEntry(id: "claude", name: "claude", detail: "Claude Opus 5", isWorking: true),
        AIAssistantRosterEntry(id: "researcher", name: "researcher", detail: "Sub-agent"),
    ]
    @State private var queued: [AIQueueItem] = [
        AIQueueItem(title: "Then check the dark palette", isPending: true),
    ]
    @State private var dialActiveID: AnyHashable?
    @State private var inspectorOpen = true
    @State private var inspectorWidth: CGFloat = 260
    @State private var inspectorTab: AIInspectorTab = .session
    @State private var commitMessage = ""
    @State private var inspectorBranch = "main"

    var body: some View {
        GalleryHeading(
            title: "Chatbot block",
            subtitle: "The full example-chatbot, driven by an AIChat — the useChat equivalent."
        )

        GalleryBlock("Try it — send a message") {
            AIChatbot(
                chat: chat,
                suggestions: [
                    "How does OKLCH work?",
                    "Show me a tool call",
                    "What can you do?",
                ],
                roster: roster,
                onToggleAgent: { id in
                    guard let index = roster.firstIndex(where: { $0.id == id }) else { return }
                    roster[index] = AIAssistantRosterEntry(
                        id: roster[index].id,
                        name: roster[index].name,
                        detail: roster[index].detail,
                        isEnabled: !roster[index].isEnabled,
                        contextFraction: roster[index].contextFraction,
                        isWorking: roster[index].isWorking,
                        hasMissingKey: roster[index].hasMissingKey
                    )
                },
                onReorderRoster: { order in
                    roster.sort { a, b in (order.firstIndex(of: a.id) ?? 0) < (order.firstIndex(of: b.id) ?? 0) }
                },
                onEditAgent: { _ in },
                onRemoveAgent: { id in roster.removeAll { $0.id == id } },
                queued: queued,
                onEditQueued: { _ in },
                onSendQueuedNow: { id in queued.removeAll { $0.id == id } },
                onCancelQueued: { id in queued.removeAll { $0.id == id } },
                onMoveQueued: { _, _ in },
                showsDial: true,
                dialActiveID: dialActiveID,
                onDialSelect: { dialActiveID = $0 },
                showsInspector: true
            ) { text, status in
                AIPromptInput(
                    text: text,
                    status: status,
                    onSubmit: { chat.sendMessage() },
                    onStop: { chat.stop() }
                ) {
                    AIPromptInputButton(systemImage: ShadcnIcon.plus, tooltip: "Attach") {}
                    AIPromptInputButton(systemImage: ShadcnIcon.globe, tooltip: "Search") {}
                }
            } inspector: {
                AIInspector(
                    isOpen: $inspectorOpen,
                    width: $inspectorWidth,
                    tab: $inspectorTab,
                    commitMessage: $commitMessage,
                    branch: $inspectorBranch,
                    session: AIInspectorSession(location: "/Users/dev/ShadKit", seatCount: roster.count, isLive: true),
                    usage: AIInspectorUsage(contextEstimate: 0.3, toolCalls: 2)
                )
            }
            .frame(height: 560)
            .shadcnBorderedBox()
            .onAppear(perform: autoSendIfRequested)
        }
    }

    /// Kicks off a turn on launch so a screenshot pass can catch the stream
    /// mid-flight. Set `SHADCN_DEMO_AUTOSEND` to the prompt.
    private func autoSendIfRequested() {
        guard let prompt = ProcessInfo.processInfo.environment["SHADCN_DEMO_AUTOSEND"],
              !prompt.isEmpty
        else { return }
        chat.sendMessage(prompt)
    }
}

/// Canned backend for the gallery. Streams reasoning, a tool call and prose so
/// every part type gets exercised.
private struct GalleryTransport: AIChatTransport {
    func send(
        messages: [UIMessage],
        options: AIChatRequestOptions
    ) -> AsyncThrowingStream<AIChatChunk, Error> {
        let prompt = messages.last?.text.lowercased() ?? ""
        let toolID = "tool-1"

        var chunks: [AIChatChunk] = []

        chunks += words("Let me work through this. The user is asking about ")
            .map { AIChatChunk.reasoningDelta($0) }
        chunks += words(prompt.isEmpty ? "the component set." : prompt)
            .map { AIChatChunk.reasoningDelta($0) }
        chunks.append(.reasoningDone(duration: 3))

        if prompt.contains("tool") {
            chunks.append(
                .toolCall(
                    UIToolPart(
                        id: toolID,
                        type: "tool-search_codebase",
                        state: .inputAvailable,
                        input: "{\n  \"query\": \"OKLCH\"\n}"
                    )
                )
            )
            chunks.append(
                .toolResult(
                    id: toolID,
                    output: "{\n  \"matches\": 3,\n  \"file\": \"OKLCH.swift\"\n}",
                    errorText: nil
                )
            )
        }

        chunks.append(.source(AISource(title: "shadcn/ui", url: URL(string: "https://ui.shadcn.com"))))

        let reply: String
        if prompt.contains("oklch") {
            reply = """
                OKLCH is a **cylindrical** form of OKLab. Converting to sRGB is three steps:

                1. Polar to Cartesian — `a = C·cos(H)`, `b = C·sin(H)`
                2. Into cone response, then cube each channel
                3. A 3×3 matrix into linear sRGB, then gamma encode

                ```swift
                let background = OKLCH(0.145, 0, 0)
                print(background.hexString) // #0A0A0A
                ```
                """
        } else if prompt.contains("tool") {
            reply = "I ran a search across the codebase — the conversion lives in `OKLCH.swift`."
        } else {
            reply = """
                This is the **AI Elements** set rendered natively in SwiftUI.

                - Streaming markdown via `AIResponse`
                - Collapsible reasoning, tools and tasks
                - The same `useChat` shape you'd use on the web
                """
        }

        chunks += words(reply).map { AIChatChunk.textDelta($0) }
        chunks.append(.finish)

        let payload = chunks
        return AsyncThrowingStream { continuation in
            let task = Task {
                for chunk in payload {
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: 24_000_000)
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Splits into word-sized deltas, keeping the trailing space so the
    /// reassembled text is unchanged.
    private func words(_ text: String) -> [String] {
        text.split(separator: " ", omittingEmptySubsequences: false)
            .map { String($0) + " " }
    }
}
