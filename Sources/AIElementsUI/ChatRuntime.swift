import Foundation
import ShadcnUI
import SwiftUI

// MARK: - Message model

/// One part of a message, mirroring the AI SDK's `UIMessagePart` union.
///
/// A message is a list of parts rather than a string because assistants
/// interleave prose, reasoning, tool calls and citations in a single turn.
public enum UIMessagePart: Identifiable, Sendable {
    case text(id: String = UUID().uuidString, String)
    case reasoning(id: String = UUID().uuidString, String, duration: Int? = nil)
    case tool(UIToolPart)
    case source(AISource)
    case file(UIFilePart)
    /// `step-start` — a boundary between agent steps.
    case stepStart(id: String = UUID().uuidString)

    public var id: String {
        switch self {
        case let .text(id, _): id
        case let .reasoning(id, _, _): id
        case let .tool(part): part.id
        case let .source(source): source.id
        case let .file(file): file.id
        case let .stepStart(id): id
        }
    }

    /// The plain text of this part, if it has any. Used for copy actions.
    public var textContent: String? {
        switch self {
        case let .text(_, value): value
        case let .reasoning(_, value, _): value
        default: nil
        }
    }
}

/// A tool invocation, mirroring `ToolUIPart`.
public struct UIToolPart: Identifiable, Sendable {
    public var id: String
    /// Fully qualified type, e.g. `tool-search_codebase`.
    public var type: String
    public var state: AIToolState
    public var input: String?
    public var output: String?
    public var errorText: String?

    public init(
        id: String = UUID().uuidString,
        type: String,
        state: AIToolState,
        input: String? = nil,
        output: String? = nil,
        errorText: String? = nil
    ) {
        self.id = id
        self.type = type
        self.state = state
        self.input = input
        self.output = output
        self.errorText = errorText
    }

    /// The bare tool name — `type.split("-").slice(1).join("-")` in the source.
    public var name: String {
        let segments = type.split(separator: "-")
        guard segments.count > 1 else { return type }
        return segments.dropFirst().joined(separator: "-")
    }
}

/// An attachment, mirroring `FileUIPart`.
public struct UIFilePart: Identifiable, Sendable {
    public var id: String
    public var filename: String
    public var mediaType: String?
    public var url: URL?

    public init(
        id: String = UUID().uuidString,
        filename: String,
        mediaType: String? = nil,
        url: URL? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mediaType = mediaType
        self.url = url
    }

    public var isImage: Bool {
        mediaType?.hasPrefix("image/") == true
    }
}

/// A single turn, mirroring `UIMessage`.
public struct UIMessage: Identifiable, Sendable {
    public var id: String
    public var role: AIMessageRole
    public var parts: [UIMessagePart]
    public var author: String?
    /// Display name of the peer this turn is answering, when it was produced
    /// because that peer's message @mentioned this message's author. `nil`
    /// for an ordinary turn — resolved by the caller at message-build time,
    /// so a later rename does not rewrite what already-posted replies show.
    public var replyToAuthor: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        role: AIMessageRole,
        parts: [UIMessagePart],
        author: String? = nil,
        replyToAuthor: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.parts = parts
        self.author = author
        self.replyToAuthor = replyToAuthor
        self.createdAt = createdAt
    }

    /// Convenience for a plain text turn.
    public init(
        id: String = UUID().uuidString, role: AIMessageRole, text: String,
        author: String? = nil, replyToAuthor: String? = nil, createdAt: Date = Date()
    ) {
        self.init(
            id: id, role: role, parts: [.text(text)], author: author,
            replyToAuthor: replyToAuthor, createdAt: createdAt)
    }

    /// All text parts joined — what a "copy message" action yields.
    public var text: String {
        parts.compactMap { part in
            if case let .text(_, value) = part { return value }
            return nil
        }
        .joined(separator: "\n\n")
    }
}

// MARK: - Status

/// Mirrors the AI SDK's `ChatStatus`.
public enum AIChatStatus: String, Sendable {
    /// The request has been sent but no token has arrived yet.
    case submitted
    /// Tokens are arriving.
    case streaming
    /// Idle — the last turn finished, or nothing has been sent.
    case ready
    /// The last request failed.
    case error

    /// The equivalent state for the composer's submit button.
    public var promptStatus: AIPromptStatus {
        switch self {
        case .submitted: .submitted
        case .streaming: .streaming
        case .ready: .ready
        case .error: .error
        }
    }
}

// MARK: - Transport

/// One event in a streamed response, mirroring the SDK's UI message stream.
public enum AIChatChunk: Sendable {
    case textDelta(String)
    case reasoningDelta(String)
    case reasoningDone(duration: Int)
    case toolCall(UIToolPart)
    case toolResult(id: String, output: String?, errorText: String?)
    case source(AISource)
    case finish
}

/// Options passed with each request, mirroring `ChatRequestOptions`.
public struct AIChatRequestOptions: Sendable {
    public var model: String?
    public var webSearch: Bool
    public var metadata: [String: String]

    public init(
        model: String? = nil,
        webSearch: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.model = model
        self.webSearch = webSearch
        self.metadata = metadata
    }
}

/// The backend behind an `AIChat`, mirroring the SDK's `ChatTransport`.
///
/// Implement this over your own endpoint; the UI layer only needs the stream.
public protocol AIChatTransport: Sendable {
    func send(
        messages: [UIMessage],
        options: AIChatRequestOptions
    ) -> AsyncThrowingStream<AIChatChunk, Error>
}

// MARK: - Chat controller

/// The Swift counterpart to the AI SDK's `useChat`.
///
/// ```swift
/// @StateObject private var chat = AIChat(transport: MyTransport())
/// ...
/// AIConversationView(chat: chat)
/// AIPromptInput(text: $chat.input, status: chat.status.promptStatus) {
///     chat.sendMessage()
/// } onStop: {
///     chat.stop()
/// }
/// ```
@MainActor
public final class AIChat: ObservableObject {
    /// The conversation so far.
    @Published public private(set) var messages: [UIMessage]
    /// Where the current turn is up to.
    @Published public private(set) var status: AIChatStatus = .ready
    /// Set when the last request failed.
    @Published public private(set) var error: Error?
    /// Two-way bound to the composer.
    @Published public var input: String = ""
    /// Request options sent with every turn.
    @Published public var options: AIChatRequestOptions

    private let transport: AIChatTransport
    private var streamTask: Task<Void, Never>?

    public init(
        transport: AIChatTransport,
        messages: [UIMessage] = [],
        options: AIChatRequestOptions = AIChatRequestOptions()
    ) {
        self.transport = transport
        self.messages = messages
        self.options = options
    }

    /// Bumped whenever the transcript changes, so `AIConversation` knows to
    /// follow the bottom.
    public var streamToken: Int { messages.count &* 1000 &+ (messages.last?.parts.count ?? 0) }

    /// Structured form; see ``AIConversationToken``.
    public var conversationToken: AIConversationToken {
        AIConversationToken(
            itemCount: messages.count,
            streamLength: messages.last?.text.count ?? 0,
            extra: messages.last?.parts.count ?? 0)
    }

    /// Appends a user turn and starts streaming the reply.
    ///
    /// - Parameter text: Defaults to `input`, which is then cleared.
    public func sendMessage(_ text: String? = nil) {
        let body = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, status == .ready || status == .error else { return }

        if text == nil { input = "" }
        error = nil
        messages.append(UIMessage(role: .user, text: body))
        startStream()
    }

    /// Cancels the in-flight turn, leaving whatever has streamed so far.
    public func stop() {
        streamTask?.cancel()
        streamTask = nil
        status = .ready
    }

    /// Drops the last assistant turn and re-runs it.
    public func regenerate() {
        guard status == .ready || status == .error else { return }
        if messages.last?.role == .assistant {
            messages.removeLast()
        }
        guard messages.last?.role == .user else { return }
        error = nil
        startStream()
    }

    /// Clears the transcript.
    public func clear() {
        stop()
        messages.removeAll()
        error = nil
    }

    // MARK: Streaming

    private func startStream() {
        streamTask?.cancel()
        status = .submitted

        let outgoing = messages
        let requestOptions = options

        streamTask = Task { [weak self] in
            guard let self else { return }
            // The assistant turn is appended up front and mutated in place as
            // chunks arrive, which is what makes streaming render smoothly.
            let replyID = UUID().uuidString
            var didAppendReply = false

            do {
                for try await chunk in transport.send(messages: outgoing, options: requestOptions) {
                    if Task.isCancelled { break }

                    if !didAppendReply {
                        messages.append(UIMessage(id: replyID, role: .assistant, parts: []))
                        didAppendReply = true
                    }
                    status = .streaming
                    apply(chunk, to: replyID)
                }
                if !Task.isCancelled { status = .ready }
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    status = .error
                }
            }
            streamTask = nil
        }
    }

    private func apply(_ chunk: AIChatChunk, to messageID: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }

        switch chunk {
        case let .textDelta(delta):
            appendText(delta, at: index)

        case let .reasoningDelta(delta):
            appendReasoning(delta, at: index)

        case let .reasoningDone(duration):
            // Stamp the elapsed time onto the reasoning part.
            if let partIndex = messages[index].parts.lastIndex(where: {
                if case .reasoning = $0 { return true }
                return false
            }), case let .reasoning(id, value, _) = messages[index].parts[partIndex] {
                messages[index].parts[partIndex] = .reasoning(id: id, value, duration: duration)
            }

        case let .toolCall(part):
            if let existing = messages[index].parts.firstIndex(where: {
                if case let .tool(candidate) = $0 { return candidate.id == part.id }
                return false
            }) {
                messages[index].parts[existing] = .tool(part)
            } else {
                messages[index].parts.append(.tool(part))
            }

        case let .toolResult(id, output, errorText):
            if let existing = messages[index].parts.firstIndex(where: {
                if case let .tool(candidate) = $0 { return candidate.id == id }
                return false
            }), case var .tool(part) = messages[index].parts[existing] {
                part.output = output
                part.errorText = errorText
                part.state = errorText == nil ? .outputAvailable : .outputError
                messages[index].parts[existing] = .tool(part)
            }

        case let .source(source):
            messages[index].parts.append(.source(source))

        case .finish:
            status = .ready
        }
    }

    /// Coalesces into the trailing text part so streaming doesn't produce one
    /// part per token.
    private func appendText(_ delta: String, at index: Int) {
        if case let .text(id, existing) = messages[index].parts.last {
            messages[index].parts[messages[index].parts.count - 1] = .text(id: id, existing + delta)
        } else {
            messages[index].parts.append(.text(delta))
        }
    }

    private func appendReasoning(_ delta: String, at index: Int) {
        if case let .reasoning(id, existing, duration) = messages[index].parts.last {
            messages[index].parts[messages[index].parts.count - 1] =
                .reasoning(id: id, existing + delta, duration: duration)
        } else {
            messages[index].parts.append(.reasoning(delta))
        }
    }
}

// MARK: - Mock transport

/// A transport that replays a canned script, for previews, demos and tests.
///
/// Streams word by word so the UI exercises the same code path a real backend
/// would drive.
public struct AIMockChatTransport: AIChatTransport {
    public var script: @Sendable ([UIMessage]) -> [AIChatChunk]
    /// Seconds between chunks.
    public var tokenDelay: Double

    public init(
        tokenDelay: Double = 0.03,
        script: @escaping @Sendable ([UIMessage]) -> [AIChatChunk]
    ) {
        self.script = script
        self.tokenDelay = tokenDelay
    }

    /// Streams a fixed reply, split into word-sized deltas.
    public init(reply: String, tokenDelay: Double = 0.03) {
        self.tokenDelay = tokenDelay
        self.script = { _ in
            reply.split(separator: " ", omittingEmptySubsequences: false)
                .map { .textDelta(String($0) + " ") } + [.finish]
        }
    }

    public func send(
        messages: [UIMessage],
        options: AIChatRequestOptions
    ) -> AsyncThrowingStream<AIChatChunk, Error> {
        let chunks = script(messages)
        let delay = tokenDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                for chunk in chunks {
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
