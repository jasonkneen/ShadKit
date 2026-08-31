import ShadcnUI
import SwiftUI

/// Renders one `UIMessage`, dispatching each part to the right AI Element.
///
/// Sources are hoisted above the body — the chatbot block renders `<Sources>`
/// before `<MessageContent>` regardless of where the parts arrived.
public struct AIMessageView: View {
    private let message: UIMessage
    private let onCopy: ((UIMessage) -> Void)?
    private let onRegenerate: ((UIMessage) -> Void)?
    private let usesAgentBubble: Bool

    @Environment(\.shadcnPalette) private var palette

    public init(
        message: UIMessage,
        onCopy: ((UIMessage) -> Void)? = nil,
        onRegenerate: ((UIMessage) -> Void)? = nil,
        usesAgentBubble: Bool = false
    ) {
        self.message = message
        self.onCopy = onCopy
        self.onRegenerate = onRegenerate
        self.usesAgentBubble = usesAgentBubble
    }

    private var sources: [AISource] {
        message.parts.compactMap {
            if case let .source(source) = $0 { return source }
            return nil
        }
    }

    private var attachments: [UIFilePart] {
        message.parts.compactMap {
            if case let .file(file) = $0 { return file }
            return nil
        }
    }

    public var body: some View {
        AIMessage(message.role) {
            if message.role == .assistant, let author = message.author {
                Text(author)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Response from \(author)")
            }
            if !attachments.isEmpty {
                AIMessageAttachments {
                    ForEach(attachments) { file in
                        AIMessageAttachment(filename: file.filename)
                    }
                }
            }

            if !sources.isEmpty {
                AISources(sources)
            }

            ForEach(message.parts) { part in
                switch part {
                case let .text(_, value):
                    AIMessageContent(value)

                case let .reasoning(_, value, duration):
                    AIReasoning(
                        content: value,
                        isStreaming: duration == nil,
                        duration: duration,
                        autoClose: false
                    )

                case let .tool(tool):
                    AITool(name: tool.name, state: tool.state) {
                        if let input = tool.input {
                            AIToolInput(json: input)
                        }
                        AIToolOutput(output: tool.output, errorText: tool.errorText)
                    }

                case .source, .file, .stepStart:
                    // Sources and files are hoisted above; step markers are
                    // structural only.
                    EmptyView()
                }
            }

            if message.role != .system {
                HStack(spacing: Space.x1) {
                    AIRelativeTimestamp(date: message.createdAt)
                    if message.role == .assistant {
                        AIMessageActions {
                            if let onCopy {
                                AIMessageAction(systemImage: ShadcnIcon.copy, tooltip: "Copy") {
                                    onCopy(message)
                                }
                            }
                            if let onRegenerate {
                                AIMessageAction(
                                    systemImage: ShadcnIcon.refresh,
                                    tooltip: "Regenerate"
                                ) {
                                    onRegenerate(message)
                                }
                            }
                        }
                    }
                }
                .frame(
                    maxWidth: message.role == .assistant ? .infinity : nil,
                    alignment: message.role == .user ? .trailing : .leading)
            }
        }
        .environment(\.aiAssistantBubbleTint, agentBubbleTint)
    }

    private var agentBubbleTint: Color? {
        guard usesAgentBubble, message.role == .assistant,
              let author = message.author, !author.isEmpty else { return nil }
        let colors = [
            palette.chart1, palette.chart2, palette.chart3,
            palette.chart4, palette.chart5,
        ]
        return colors[Self.agentColorSlot(for: author)]
            .opacity(palette.isDark ? 0.14 : 0.09)
    }

    /// Stable across launches (unlike Swift's randomized `Hasher`) so each
    /// auto-named agent keeps the same subtle bubble colour.
    static func agentColorSlot(for author: String) -> Int {
        var hash: UInt32 = 2_166_136_261
        for byte in author.lowercased().utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return Int(hash % 5)
    }
}

private struct AIRelativeTimestamp: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(Self.label(for: date, now: context.date))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.72))
                .help(date.formatted(date: .abbreviated, time: .shortened))
                .accessibilityLabel(
                    "Sent \(date.formatted(date: .complete, time: .shortened))")
        }
    }

    static func label(for date: Date, now: Date) -> String {
        let seconds = max(Int(now.timeIntervalSince(date)), 0)
        if seconds < 60 { return "now" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3_600)h" }
        if seconds < 604_800 { return "\(seconds / 86_400)d" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

/// The scrolling transcript for an `AIChat`.
public struct AIConversationView: View {
    @ObservedObject private var chat: AIChat
    private let emptyState: AIConversationEmptyState?

    public init(chat: AIChat, emptyState: AIConversationEmptyState? = nil) {
        self.chat = chat
        self.emptyState = emptyState
    }

    public var body: some View {
        AIConversation(token: chat.conversationToken) {
            if chat.messages.isEmpty, let emptyState {
                emptyState
            }

            ForEach(chat.messages) { message in
                AIMessageView(
                    message: message,
                    onCopy: { copy($0.text) },
                    onRegenerate: { _ in chat.regenerate() }
                )
            }

            // The gap between submitting and the first token.
            if chat.status == .submitted {
                AIMessage(.assistant) {
                    AIShimmer("Thinking...", duration: 1)
                }
            }

            if let error = chat.error {
                ShadcnAlert(variant: .destructive, systemImage: ShadcnIcon.alertTriangle) {
                    ShadcnAlertTitle("Something went wrong")
                    ShadcnAlertDescription(error.localizedDescription)
                }
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

/// The `example-chatbot` block: transcript, suggestions and composer, wired to
/// an `AIChat`.
///
/// This is the drop-in — hand it a chat and you have a working chat surface.
public struct AIChatbot<Composer: View>: View {
    @ObservedObject private var chat: AIChat
    private let suggestions: [String]
    private let composer: (Binding<String>, AIPromptStatus) -> Composer

    public init(
        chat: AIChat,
        suggestions: [String] = [],
        @ViewBuilder composer: @escaping (Binding<String>, AIPromptStatus) -> Composer
    ) {
        self.chat = chat
        self.suggestions = suggestions
        self.composer = composer
    }

    public var body: some View {
        VStack(spacing: Space.x4) {
            AIConversationView(
                chat: chat,
                emptyState: AIConversationEmptyState(systemImage: ShadcnIcon.sparkles)
            )
            .frame(maxHeight: .infinity)

            VStack(spacing: Space.x3) {
                if !suggestions.isEmpty, chat.messages.isEmpty {
                    AISuggestions(suggestions) { chat.sendMessage($0) }
                }
                composer($chat.input, chat.status.promptStatus)
            }
            .padding(.horizontal, Space.x4)
            .padding(.bottom, Space.x4)
        }
    }
}

extension AIChatbot where Composer == AIPromptInput<EmptyView, EmptyView, EmptyView> {
    /// The stock composer.
    public init(chat: AIChat, suggestions: [String] = []) {
        self.init(chat: chat, suggestions: suggestions) { text, status in
            AIPromptInput(
                text: text,
                status: status,
                onSubmit: { chat.sendMessage() },
                onStop: { chat.stop() }
            )
        }
    }
}
