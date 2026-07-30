import ShadcnUI
import SwiftUI

/// A complete assistant surface: transcript, queue and composer.
///
/// This is the whole panel, not just the transcript — the composer, model and
/// effort pickers are ShadKit too, so an embedding app gets one coherent
/// surface rather than SwiftUI content inside a foreign frame.
///
/// State is driven from outside (`AIAssistantPanelModel`) so an AppKit host can
/// keep feeding it exactly as it fed the view it replaces.
@MainActor
public final class AIAssistantPanelModel: ObservableObject {
    @Published public var messages: [UIMessage] = []
    /// The answer currently arriving, rendered as a real assistant turn.
    @Published public var streamingText: String?
    @Published public var isThinking = false
    @Published public var thinkingLabel = "Thinking"
    @Published public var queued: [String] = []
    /// Tool calls for the turn in flight.
    ///
    /// Kept apart from `messages` on purpose: hosts rebuild `messages` wholesale
    /// from their own transcript, which would wipe cards folded in there.
    @Published public var tools: [UIToolPart] = []
    @Published public var input = ""
    @Published public var model: String?
    @Published public var effort: String?
    /// Agent/provider choices — Claude, Codex, opencode…
    @Published public var agents: [(value: String, label: String)] = []
    @Published public var agent: String?
    @Published public var models: [(value: String, label: String)] = []
    @Published public var efforts: [(value: String, label: String)] = []
    @Published public var hasFiles = false

    /// Invoked when the user submits. `(request, model, effort)` mirrors the
    /// existing panel's submit signature.
    public var onSubmit: ((String, String, String) -> Void)?
    public var onStop: (() -> Void)?
    public var onNewChat: (() -> Void)?

    public init() {}

    public var status: AIPromptStatus {
        if isThinking || streamingText != nil { return .streaming }
        return .ready
    }

    /// Bumped on any visible change so the conversation stays pinned.
    public var streamToken: Int {
        messages.count &* 100_000
            &+ (streamingText?.count ?? 0)
            &+ (isThinking ? 1 : 0)
            &+ queued.count
            &+ tools.count
    }

    /// Folds a tool event into the live list. A result carries no name, so it
    /// updates the call it matches rather than appending a second card.
    public func applyTool(
        id: String,
        name: String,
        state: AIToolState,
        input: String? = nil,
        output: String? = nil,
        errorText: String? = nil
    ) {
        if let index = tools.firstIndex(where: { $0.id == id }) {
            tools[index].state = state
            if let output { tools[index].output = output }
            if let errorText { tools[index].errorText = errorText }
            if !name.isEmpty { tools[index].type = "tool-" + name }
        } else {
            tools.append(
                UIToolPart(
                    id: id,
                    type: "tool-" + (name.isEmpty ? "tool" : name),
                    state: state, input: input, output: output, errorText: errorText))
        }
    }

    /// Sends the composer's contents. Public because an AppKit host may need
    /// to submit on its own key handling rather than the SwiftUI button.
    public func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        onSubmit?(text, model ?? "Auto", effort ?? "Auto")
    }
}

/// The panel.
public struct AIAssistantPanel: View {
    @ObservedObject private var model: AIAssistantPanelModel
    private let showsHeader: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(model: AIAssistantPanelModel, showsHeader: Bool = true) {
        self.model = model
        self.showsHeader = showsHeader
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header
                ShadcnSeparator()
            }

            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !model.queued.isEmpty {
                queue
            }

            composer
                .padding(Space.x3)
        }
        .background(palette.background)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Space.x2) {
            ShadcnIconView(ShadcnIcon.sparkles, size: 14)
                .foregroundStyle(palette.mutedForeground)
            Text("Chat")
                .font(theme.typography.sans(theme.typography.sm, weight: .medium))
            Spacer()
            ShadcnButton(icon: ShadcnIcon.plus, variant: .ghost, size: .iconSM) {
                model.onNewChat?()
            }
            .shadcnTooltip("New chat")
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x2)
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcript: some View {
        if model.messages.isEmpty, model.streamingText == nil, !model.isThinking,
           model.tools.isEmpty {
            AIConversationEmptyState(
                title: "Ask anything",
                description: "Choose an agent, ask a question, and keep chatting here.",
                systemImage: ShadcnIcon.sparkles
            )
        } else {
            AIConversation(streamToken: model.streamToken) {
                ForEach(model.messages) { message in
                    AIMessageView(message: message, onCopy: { copy($0.text) })
                }

                // Above the answer they feed, matching how the assistant
                // actually worked: call the tool, then explain the result.
                if !model.tools.isEmpty {
                    AIMessage(.assistant) {
                        ForEach(model.tools) { tool in
                            AITool(name: tool.name, state: tool.state) {
                                if let input = tool.input { AIToolInput(json: input) }
                                AIToolOutput(output: tool.output, errorText: tool.errorText)
                            }
                        }
                    }
                }

                if let streaming = model.streamingText, !streaming.isEmpty {
                    AIMessageView(
                        message: UIMessage(id: "in-flight", role: .assistant, text: streaming))
                } else if model.isThinking {
                    AIMessage(.assistant) {
                        HStack(spacing: Space.x2) {
                            AILoader(size: 14)
                            AIShimmer(model.thinkingLabel, duration: 1.2)
                        }
                    }
                }
            }
        }
    }

    // MARK: Queue

    private var queue: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            ForEach(Array(model.queued.enumerated()), id: \.offset) { _, text in
                HStack(spacing: Space.x2) {
                    Circle()
                        .strokeBorder(palette.mutedForeground.opacity(0.5), lineWidth: 1)
                        .frame(width: 8, height: 8)
                    Text(text)
                        .font(theme.typography.sans(theme.typography.xs))
                        .foregroundStyle(palette.mutedForeground)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, Space.x4)
        .padding(.vertical, Space.x2)
    }

    // MARK: Composer

    private var composer: some View {
        AIPromptInput(
            text: $model.input,
            placeholder: "Ask anything",
            status: model.status,
            // A sidebar composer rests at one line; `min-h-16` reads as a big
            // empty box that visibly shrinks once content arrives.
            style: .compact,
            onSubmit: { model.submit() },
            onStop: { model.onStop?() }
        ) {
            if model.hasFiles {
                AIPromptInputButton(systemImage: ShadcnIcon.paperclip, tooltip: "Files") {}
            }
            if !model.agents.isEmpty {
                ShadcnSelect(
                    "Agent", selection: $model.agent, width: 104,
                    isCompact: true, edge: .top, options: model.agents)
            }
            if !model.models.isEmpty {
                ShadcnSelect(
                    "Model", selection: $model.model, width: 126,
                    isCompact: true, edge: .top, options: model.models)
            }
            if !model.efforts.isEmpty {
                ShadcnSelect(
                    "Effort", selection: $model.effort, width: 96,
                    isCompact: true, edge: .top, options: model.efforts)
            }
        }
    }

    private func copy(_ text: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

#if canImport(AppKit)
import AppKit
#endif
