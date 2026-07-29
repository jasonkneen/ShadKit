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

    public init(
        message: UIMessage,
        onCopy: ((UIMessage) -> Void)? = nil,
        onRegenerate: ((UIMessage) -> Void)? = nil
    ) {
        self.message = message
        self.onCopy = onCopy
        self.onRegenerate = onRegenerate
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

            if message.role == .assistant, onCopy != nil || onRegenerate != nil {
                AIMessageActions {
                    if let onCopy {
                        AIMessageAction(systemImage: ShadcnIcon.copy, tooltip: "Copy") {
                            onCopy(message)
                        }
                    }
                    if let onRegenerate {
                        AIMessageAction(systemImage: ShadcnIcon.refresh, tooltip: "Regenerate") {
                            onRegenerate(message)
                        }
                    }
                }
            }
        }
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
        AIConversation(streamToken: chat.streamToken) {
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
