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
    /// A leading avatar, drawn to the side of the bubble. Type-erased so this
    /// stays a concrete, non-generic `View` for source compatibility.
    private let avatar: (() -> AnyView)?
    /// The message this one is replying to, shown as a quoted preview above
    /// the content.
    private let replyTo: UIMessage?
    /// A short usage/cost string (e.g. token count), shown as a badge next to
    /// the timestamp.
    private let usageBadge: String?
    /// Extra actions appended after Copy/Regenerate (e.g. fork, hand off).
    private let accessoryActions: (() -> AnyView)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        message: UIMessage,
        onCopy: ((UIMessage) -> Void)? = nil,
        onRegenerate: ((UIMessage) -> Void)? = nil,
        usesAgentBubble: Bool = false,
        avatar: (() -> AnyView)? = nil,
        replyTo: UIMessage? = nil,
        usageBadge: String? = nil,
        accessoryActions: (() -> AnyView)? = nil
    ) {
        self.message = message
        self.onCopy = onCopy
        self.onRegenerate = onRegenerate
        self.usesAgentBubble = usesAgentBubble
        self.avatar = avatar
        self.replyTo = replyTo
        self.usageBadge = usageBadge
        self.accessoryActions = accessoryActions
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
        HStack(alignment: .top, spacing: Space.x2) {
            if let avatar {
                avatar()
            }
            bubble
        }
        .environment(\.aiAssistantBubbleTint, agentBubbleTint)
    }

    @ViewBuilder
    private var bubble: some View {
        AIMessage(message.role) {
            if let replyTo {
                replyPreview(replyTo)
            }
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
                    if let usageBadge {
                        ShadcnBadge(usageBadge, variant: .outline)
                    }
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
                            accessoryActions?()
                        }
                    }
                }
                .frame(
                    maxWidth: message.role == .assistant ? .infinity : nil,
                    alignment: message.role == .user ? .trailing : .leading)
            }
        }
    }

    private func replyPreview(_ replyTo: UIMessage) -> some View {
        HStack(spacing: Space.x1_5) {
            Rectangle()
                .fill(palette.mutedForeground.opacity(0.4))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 1) {
                if let author = replyTo.author {
                    Text(author)
                        .font(theme.typography.sans(theme.typography.xs, weight: .semibold))
                        .foregroundStyle(palette.mutedForeground)
                }
                Text(replyTo.text)
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, Space.x1)
        .padding(.horizontal, Space.x2)
        .background(palette.muted.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm, style: .continuous))
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
/// Ports `chat-view.tsx`'s shell: an optional seat rail above the transcript,
/// an optional dial scrubber, a queue strip once turns are queued, and an
/// optional docked inspector. Every addition is values-in — no transport, no
/// routing, no seat policy; the host still owns all of that.
public struct AIChatbot<Composer: View, Inspector: View>: View {
    @ObservedObject private var chat: AIChat
    private let suggestions: [String]
    private let composer: (Binding<String>, AIPromptStatus) -> Composer
    private let inspector: () -> Inspector

    private let roster: [AIAssistantRosterEntry]
    private let onToggleAgent: (String) -> Void
    private let onReorderRoster: (([String]) -> Void)?
    private let onEditAgent: ((String) -> Void)?
    private let onRemoveAgent: ((String) -> Void)?

    private let queued: [AIQueueItem]
    private let onEditQueued: (AIQueueItem.ID) -> Void
    private let onSendQueuedNow: (AIQueueItem.ID) -> Void
    private let onCancelQueued: (AIQueueItem.ID) -> Void
    private let onMoveQueued: (AIQueueItem.ID, Int) -> Void

    private let showsDial: Bool
    private let dialActiveID: AnyHashable?
    private let onDialSelect: (AnyHashable) -> Void

    private let showsInspector: Bool

    public init(
        chat: AIChat,
        suggestions: [String] = [],
        roster: [AIAssistantRosterEntry] = [],
        onToggleAgent: @escaping (String) -> Void = { _ in },
        onReorderRoster: (([String]) -> Void)? = nil,
        onEditAgent: ((String) -> Void)? = nil,
        onRemoveAgent: ((String) -> Void)? = nil,
        queued: [AIQueueItem] = [],
        onEditQueued: @escaping (AIQueueItem.ID) -> Void = { _ in },
        onSendQueuedNow: @escaping (AIQueueItem.ID) -> Void = { _ in },
        onCancelQueued: @escaping (AIQueueItem.ID) -> Void = { _ in },
        onMoveQueued: @escaping (AIQueueItem.ID, Int) -> Void = { _, _ in },
        showsDial: Bool = false,
        dialActiveID: AnyHashable? = nil,
        onDialSelect: @escaping (AnyHashable) -> Void = { _ in },
        showsInspector: Bool = false,
        @ViewBuilder composer: @escaping (Binding<String>, AIPromptStatus) -> Composer,
        @ViewBuilder inspector: @escaping () -> Inspector = { EmptyView() }
    ) {
        self.chat = chat
        self.suggestions = suggestions
        self.roster = roster
        self.onToggleAgent = onToggleAgent
        self.onReorderRoster = onReorderRoster
        self.onEditAgent = onEditAgent
        self.onRemoveAgent = onRemoveAgent
        self.queued = queued
        self.onEditQueued = onEditQueued
        self.onSendQueuedNow = onSendQueuedNow
        self.onCancelQueued = onCancelQueued
        self.onMoveQueued = onMoveQueued
        self.showsDial = showsDial
        self.dialActiveID = dialActiveID
        self.onDialSelect = onDialSelect
        self.showsInspector = showsInspector
        self.composer = composer
        self.inspector = inspector
    }

    private var dialTicks: [AIDialTick] {
        AIDial.ticks(
            forMessages: chat.messages.map { message in
                (id: AnyHashable(message.id), role: message.role, preview: message.text)
            }
        )
    }

    public var body: some View {
        HStack(spacing: 0) {
            shell
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsInspector {
                inspector()
            }
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            if !roster.isEmpty {
                AIAssistantRosterRail(
                    entries: roster,
                    onToggle: onToggleAgent,
                    onReorder: onReorderRoster,
                    onEdit: onEditAgent,
                    onRemove: onRemoveAgent
                )
                ShadcnSeparator()
            }

            // The composer is built once, at one structural position, below
            // both branches — earlier this called `composer(...)` from two
            // different places in the tree, which SwiftUI treats as two
            // different identities: sending the first message tore one
            // instance down and built the other, resetting the textarea's
            // focus and dropping any in-flight IME composition.
            VStack(spacing: Space.x4) {
                if chat.messages.isEmpty {
                    // Centered start state — matches the source's empty
                    // conversation, before any turn has happened.
                    Spacer(minLength: 0)
                    AIConversationEmptyState(systemImage: ShadcnIcon.sparkles)
                    if !suggestions.isEmpty {
                        AISuggestions(suggestions) { chat.sendMessage($0) }
                    }
                    Spacer(minLength: 0)
                } else {
                    // The dial is a read-head for the transcript, so it rides
                    // as an overlay on the scroller's trailing edge — stacked
                    // underneath it, a vertical rail of hairlines would just
                    // eat height and point at nothing.
                    AIConversationView(
                        chat: chat,
                        emptyState: AIConversationEmptyState(systemImage: ShadcnIcon.sparkles)
                    )
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .trailing) {
                        if showsDial {
                            AIDial(
                                ticks: dialTicks,
                                activeID: dialActiveID,
                                side: .trailing,
                                onSelect: onDialSelect
                            )
                        }
                    }

                    if !queued.isEmpty {
                        AIQueueStrip(
                            items: queued,
                            onEdit: onEditQueued,
                            onSendNow: onSendQueuedNow,
                            onCancel: onCancelQueued,
                            onMove: onMoveQueued
                        )
                    }
                }

                composer($chat.input, chat.status.promptStatus)
                    .frame(maxWidth: chat.messages.isEmpty ? 640 : .infinity)
            }
            .padding(.horizontal, Space.x4)
            .padding(.bottom, Space.x4)
        }
    }
}

extension AIChatbot where Composer == AIPromptInput<EmptyView, EmptyView, EmptyView>, Inspector == EmptyView {
    /// The stock composer, no inspector docked.
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
