import AIElementsUI
import ShadcnUI
import SwiftUI

// MARK: - Conversation

struct ConversationDemo: View {
    @State private var branch = 0
    @State private var dialActiveID: AnyHashable? = "m2"

    private static let dialTicks = AIDial.ticks(forMessages: [
        (id: AnyHashable("m1"), role: .user, preview: "Can you explain OKLCH?"),
        (id: AnyHashable("m2"), role: .assistant, preview: "OKLCH is a cylindrical form of OKLab."),
        (id: AnyHashable("m3"), role: .user, preview: "How does the gamma step work?"),
        (id: AnyHashable("m4"), role: .assistant, preview: "It applies the sRGB transfer function."),
    ])

    var body: some View {
        GalleryHeading(
            title: "Conversation",
            subtitle: "Message, MessageContent, actions, attachments and branch selector."
        )

        GalleryBlock("Messages") {
            VStack(alignment: .leading, spacing: Space.x8) {
                AIMessage(.user) {
                    AIMessageContent("Can you explain how OKLCH maps to sRGB?")
                }

                AIMessage(.assistant) {
                    AIMessageContent(
                        """
                        OKLCH is a **cylindrical** form of OKLab. Converting runs in three steps:

                        1. Polar to Cartesian — `a = C·cos(H)`, `b = C·sin(H)`
                        2. OKLab to cone response, then cube each channel
                        3. A 3×3 matrix into linear sRGB, then gamma encode

                        The matrix rows sum to exactly 1, which is why any achromatic
                        colour comes out perfectly neutral.
                        """
                    )
                    AIMessageActions {
                        AIMessageAction(systemImage: ShadcnIcon.copy, tooltip: "Copy") {}
                        AIMessageAction(systemImage: ShadcnIcon.refresh, tooltip: "Regenerate") {}
                        AIMessageAction(systemImage: ShadcnIcon.thumbsUp, tooltip: "Good response") {}
                        AIMessageAction(systemImage: ShadcnIcon.thumbsDown, tooltip: "Bad response") {}
                    }
                }
            }
        }

        GalleryBlock("Message view — avatar, reply, usage, accessory") {
            AIMessageView(
                message: UIMessage(
                    role: .assistant,
                    text: "Renamed the branch and pushed.",
                    author: "Claude"),
                onCopy: { _ in },
                avatar: {
                    AnyView(
                        Circle().fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                    )
                },
                replyTo: UIMessage(role: .user, text: "Can you rename the feature branch?"),
                usageBadge: "1.2k tokens",
                accessoryActions: {
                    AnyView(
                        AIMessageAction(systemImage: ShadcnIcon.gitBranch, tooltip: "Fork") {}
                    )
                }
            )
        }

        GalleryBlock("Branch selector") {
            AIMessageBranchSelector(index: $branch, total: 3)
        }

        GalleryBlock("Attachments") {
            AIMessageAttachments {
                AIMessageAttachment(filename: "diagram.png")
                AIMessageAttachment(filename: "notes.pdf")
            }
        }

        GalleryBlock("Attachment card — actions & error") {
            AIMessageAttachments {
                AIMessageAttachment(
                    filename: "screenshot.png",
                    actions: [
                        AIMessageAttachmentAction(label: "Preview", systemImage: ShadcnIcon.eye) {},
                        AIMessageAttachmentAction(label: "Download", systemImage: ShadcnIcon.arrowDown) {},
                    ],
                    onRemove: {}
                )
                AIMessageAttachment(filename: "upload-failed.zip", errorText: "Upload failed", onRemove: {})
            }
        }

        GalleryBlock("System event") {
            VStack(spacing: Space.x2) {
                AISystemEvent("researcher joined the session", kind: .seatAdd)
                AISystemEvent("Switched to Claude Opus 5", kind: .seatModel)
                AISystemEvent("YOLO mode enabled", kind: .modeYolo)
                AISystemEvent("No API key configured for Grok", kind: .missingKey)
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Dial") {
            // The rail is a sibling of the scroller it scrubs, pinned to an
            // edge — not a bare inline widget — so it needs something
            // scrollable beside it to make sense.
            ZStack(alignment: .trailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.x4) {
                        AIMessage(.user) {
                            AIMessageContent("Can you explain OKLCH?")
                        }
                        AIMessage(.assistant) {
                            AIMessageContent("OKLCH is a cylindrical form of OKLab.")
                        }
                        AIMessage(.user) {
                            AIMessageContent("How does the gamma step work?")
                        }
                        AIMessage(.assistant) {
                            AIMessageContent("It applies the sRGB transfer function.")
                        }
                    }
                    .padding(.trailing, Space.x8)
                }
                AIDial(ticks: Self.dialTicks, activeID: dialActiveID, side: .trailing) { dialActiveID = $0 }
            }
            .frame(height: 240)
            .frame(maxWidth: 620)
        }

        GalleryBlock("Empty state") {
            AIConversationEmptyState(systemImage: ShadcnIcon.sparkles)
                .frame(height: 200)
                .shadcnBorderedBox()
        }

        GalleryBlock("Suggestions") {
            AISuggestions(
                [
                    "Explain this codebase",
                    "Write unit tests",
                    "Find the performance bottleneck",
                    "Refactor for clarity",
                ]
            ) { _ in }
        }
    }
}

// MARK: - Prompt input

struct PromptDemo: View {
    @State private var ready = ""
    @State private var streaming = "Explain the render loop"
    @State private var model: String? = "opus"
    @State private var composerText = ""
    @State private var attachments: [AIPromptInputAttachments.Item] = [
        .init(filename: "diagram.png", byteSize: 482_000, state: .done),
        .init(filename: "recording.mp4", byteSize: 12_400_000, state: .uploading),
        .init(filename: "notes.pdf", errorText: "Over 10 MB"),
    ]

    private static let mentionPalette = AIPromptPalette(
        trigger: "@",
        groups: [
            ShadcnCommandGroup(
                id: "agents",
                title: "Agents",
                items: [
                    ShadcnCommandItem(id: "claude", title: "Claude", icon: ShadcnIcon.sparkles),
                    ShadcnCommandItem(id: "researcher", title: "researcher"),
                ]
            ),
        ]
    )

    private static let slashPalette = AIPromptPalette(
        trigger: "/",
        groups: [
            ShadcnCommandGroup(
                id: "commands",
                title: "Commands",
                items: [
                    ShadcnCommandItem(id: "clear", title: "clear", subtitle: "Clear the conversation"),
                    ShadcnCommandItem(id: "compact", title: "compact", subtitle: "Compact the context"),
                ]
            ),
        ]
    )

    var body: some View {
        GalleryHeading(
            title: "Prompt input",
            subtitle: "The composer, in each of its four ChatStatus states."
        )

        GalleryBlock("Ready") {
            AIPromptInput(text: $ready, status: .ready, onSubmit: {}) {
                AIPromptInputButton(systemImage: ShadcnIcon.plus, tooltip: "Add attachment") {}
                AIPromptInputButton(systemImage: ShadcnIcon.globe, title: "Search", isActive: true) {}
                AIPromptInputModelSelect(
                    selection: $model,
                    models: [
                        ("opus", "Claude Opus 5"),
                        ("sonnet", "Claude Sonnet 5"),
                    ]
                )
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Streaming") {
            AIPromptInput(text: $streaming, status: .streaming, onSubmit: {}, onStop: {}) {
                AIPromptInputButton(systemImage: ShadcnIcon.microphone, tooltip: "Dictate") {}
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Attachment chips & mentions") {
            AIPromptInput(
                text: $composerText,
                status: .ready,
                palettes: [Self.mentionPalette, Self.slashPalette],
                onSubmit: {},
                onPaletteSelect: { _, _ in }
            ) {
                AIPromptInputAttachments(items: attachments) { id in
                    attachments.removeAll { $0.id == id }
                }
            } tools: {
                AIPromptInputButton(systemImage: ShadcnIcon.plus, tooltip: "Add attachment") {}
            } trailing: {
                EmptyView()
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Submitted & error") {
            VStack(spacing: Space.x4) {
                AIPromptInput(text: .constant("Thinking…"), status: .submitted, onSubmit: {})
                AIPromptInput(text: .constant("Failed request"), status: .error, onSubmit: {})
            }
            .frame(maxWidth: 620)
        }
    }
}

// MARK: - Reasoning

struct ThinkingDemo: View {
    @State private var isStreaming = true

    private static let waveformSamples: [CGFloat] = [
        0.2, 0.5, 0.8, 0.4, 0.9, 0.3, 0.6, 0.7, 0.2, 0.5,
        0.4, 0.8, 0.3, 0.6, 0.9, 0.2, 0.5, 0.7, 0.3, 0.4,
    ]

    var body: some View {
        GalleryHeading(
            title: "Reasoning",
            subtitle: "Reasoning, ChainOfThought, Loader and Shimmer."
        )

        GalleryBlock("Loader & Shimmer") {
            HStack(spacing: Space.x6) {
                AILoader(size: 16)
                AILoader(size: 24)
                AIShimmer("Thinking...", duration: 1)
            }
        }

        GalleryBlock("Waveform") {
            VStack(alignment: .leading, spacing: Space.x4) {
                VStack(alignment: .leading, spacing: Space.x1) {
                    Text("Static").font(.system(size: 11)).foregroundStyle(.secondary)
                    AIWaveform(samples: Self.waveformSamples, mode: .static)
                        .frame(width: 220, height: 40)
                }
                VStack(alignment: .leading, spacing: Space.x1) {
                    Text("Scrolling").font(.system(size: 11)).foregroundStyle(.secondary)
                    AIWaveform(samples: Self.waveformSamples, mode: .scrolling)
                        .frame(width: 220, height: 40)
                }
            }
        }

        GalleryBlock("Reasoning — streaming") {
            AIReasoning(
                content: "The user wants a colour conversion. I should start from the OKLab matrices rather than approximating through HSL, since the round-trip error there is visible on mid-greys.",
                isStreaming: isStreaming,
                autoClose: false
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Reasoning — settled") {
            AIReasoning(
                content: "Checked the matrix row sums; they come to 1.0, so achromatic input stays achromatic.",
                isStreaming: false,
                duration: 4,
                defaultOpen: true,
                autoClose: false
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Chain of thought") {
            AIChainOfThought(defaultOpen: true) {
                AIChainOfThoughtStep(
                    label: "Searching the registry",
                    description: "Looking for the canonical token values",
                    status: .complete
                ) {
                    AIChainOfThoughtSearchResults([
                        "ui.shadcn.com", "registry.ai-sdk.dev", "tailwindcss.com",
                    ])
                }
                AIChainOfThoughtStep(
                    label: "Converting OKLCH to sRGB",
                    description: "Verifying against known hex values",
                    status: .active
                )
                AIChainOfThoughtStep(
                    label: "Writing the Swift port",
                    status: .pending,
                    isLast: true
                )
            }
            .frame(maxWidth: 620)
        }
    }
}

// MARK: - Tool & Task

struct ToolingDemo: View {
    var body: some View {
        GalleryHeading(
            title: "Tool & Task",
            subtitle: "Tool call records, task lists and source citations."
        )

        GalleryBlock("Tool — every state") {
            VStack(spacing: Space.x3) {
                ForEach(AIToolState.allCases, id: \.self) { state in
                    AITool(name: "search_codebase", state: state) {
                        AIToolInput(json: "{\n  \"query\": \"OKLCH\",\n  \"limit\": 10\n}")
                    }
                }
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Tool — expanded with output") {
            AITool(name: "read_file", state: .outputAvailable, defaultOpen: true) {
                AIToolInput(json: "{\n  \"path\": \"Sources/ShadcnUI/Theme/OKLCH.swift\"\n}")
                AIToolOutput(output: "{\n  \"lines\": 214,\n  \"language\": \"swift\"\n}")
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Tool — error") {
            AITool(name: "run_tests", state: .outputError, defaultOpen: true) {
                AIToolOutput(errorText: "Build failed: no such module 'Shiki'")
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Tool — marker row") {
            VStack(alignment: .leading, spacing: Space.x1) {
                AIToolMarker(name: "search_codebase", state: .outputAvailable)
                AIToolMarker(name: "read_file", state: .inputAvailable)
                AIToolMarker(name: "run_tests", state: .outputError)
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Activity panel") {
            AIActivityPanel(
                events: [
                    AIActivityEvent(toolName: "search_codebase", duration: 0.8),
                    AIActivityEvent(toolName: "read_file", duration: 0.2, subagent: "researcher"),
                    AIActivityEvent(toolName: "run_tests", duration: 4.6),
                ],
                changes: [
                    AIActivityFileChange(path: "OKLCH.swift", additions: 12, deletions: 3),
                ]
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Task") {
            AITask(title: "Porting the primitives") {
                AITaskItem {
                    Text("Read")
                    AITaskItemFile("button.tsx", systemImage: ShadcnIcon.file)
                }
                AITaskItem {
                    Text("Wrote")
                    AITaskItemFile("Button.swift", systemImage: ShadcnIcon.file)
                    Text("and")
                    AITaskItemFile("Badge.swift", systemImage: ShadcnIcon.file)
                }
                AITaskItem("Verified against the registry snapshot")
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Sources") {
            AISources(
                [
                    AISource(title: "shadcn/ui — Button", url: URL(string: "https://ui.shadcn.com")),
                    AISource(title: "AI Elements — Tool", url: URL(string: "https://ai-sdk.dev")),
                    AISource(title: "Tailwind CSS — Spacing", url: URL(string: "https://tailwindcss.com")),
                ],
                defaultOpen: true
            )
            .frame(maxWidth: 620)
        }
    }
}

// MARK: - Response & code

struct ContentDemo: View {
    private let htmlPreviewRenderer = AnyAICodeBlockPreviewRenderer(GalleryCodeBlockPreviewRenderer())

    var body: some View {
        GalleryHeading(
            title: "Response & Code",
            subtitle: "Markdown rendering, syntax-highlighted code, artifacts and citations."
        )

        GalleryBlock("Response") {
            AIResponse(
                """
                ## Converting OKLCH

                The conversion is **three matrix multiplies** and a gamma step.

                - Polar to Cartesian
                - Cone response, cubed
                - Matrix into linear sRGB

                > Row sums are exactly 1, so greys stay grey.

                Use `OKLCH(0.145, 0, 0)` for the dark background.
                """
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Code block") {
            AICodeBlock(
                code: """
                public var linearSRGB: (r: Double, g: Double, b: Double) {
                    let (labL, labA, labB) = oklab
                    // Björn Ottosson's LMS' basis.
                    let lPrime = labL + 0.3963377774 * labA + 0.2158037573 * labB
                    return (r: 4.0767416621 * long, g: 0, b: 0)
                }
                """,
                language: "swift",
                showLineNumbers: true
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Code block — preview toggle") {
            AICodeBlock(
                code: "<button style=\"padding:8px 16px\">Approve</button>",
                language: "html"
            )
            .aiCodeBlockPreviewRenderer(htmlPreviewRenderer)
            .frame(maxWidth: 620)
        }

        GalleryBlock("Artifact") {
            AIArtifact(title: "OKLCH.swift", description: "214 lines · Swift") {
                AIArtifactAction(systemImage: ShadcnIcon.copy, tooltip: "Copy") {}
                AIArtifactAction(systemImage: ShadcnIcon.refresh, tooltip: "Regenerate") {}
                AIArtifactAction(systemImage: ShadcnIcon.xMark, tooltip: "Close") {}
            } content: {
                AICodeBlock(
                    code: "let white = OKLCH(1, 0, 0)\nprint(white.hexString) // #FFFFFF",
                    language: "swift"
                )
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Inline citation") {
            AIInlineCitation(
                text: "The neutral-950 token resolves to #0A0A0A.",
                sources: [
                    AICitationSource(
                        title: "shadcn/ui — Colours",
                        url: "https://ui.shadcn.com/colors",
                        description: "The base colour scales shipped with the CLI.",
                        quote: "background: oklch(0.145 0 0)"
                    ),
                    AICitationSource(
                        title: "Tailwind — Neutral",
                        url: "https://tailwindcss.com/docs/colors"
                    ),
                ]
            )
            .frame(maxWidth: 620)
        }
    }
}

// MARK: - Plan & queue

struct WorkflowDemo: View {
    @State private var questionSelections: [String: Set<String>] = [:]
    @State private var questionWriteIns: [String: String] = [:]
    @State private var todoItems: [AITodoItem] = [
        AITodoItem(title: "Convert the OKLCH token set", status: .completed),
        AITodoItem(title: "Port the 26 shadcn primitives", status: .inProgress, actor: "claude"),
        AITodoItem(title: "Port the AI Elements set", status: .pending),
    ]
    @State private var queueStripItems: [AIQueueItem] = [
        AIQueueItem(title: "Wire the package into Infinitty", isPending: true),
        AIQueueItem(title: "Screenshot each section", isPending: true, attachments: ["spec.pdf"]),
    ]

    private static let questions: [AIQuestion] = [
        // `allowsWriteIn: false` (0.3.1) — a strict pick-one with no
        // "Other…" field, for questions that forbid a free-text answer.
        AIQuestion(
            prompt: "Which registry should this match?",
            kind: .choice(["shadcn/ui", "AI Elements"]),
            allowsWriteIn: false
        ),
        AIQuestion(prompt: "Which platforms need coverage?", kind: .multiSelect(["macOS", "iOS", "visionOS"])),
        AIQuestion(prompt: "Should the port stay dependency-free?", kind: .confirm),
    ]

    var body: some View {
        GalleryHeading(
            title: "Plan & Queue",
            subtitle: "Plan, Queue, Confirmation, Checkpoint and Context."
        )

        GalleryBlock("Plan") {
            AIPlan(
                title: "Port ShadKit",
                description: "Reproduce shadcn/ui and AI Elements as native SwiftUI."
            ) {
                AITaskItem("Convert the OKLCH token set")
                AITaskItem("Port the 26 shadcn primitives")
                AITaskItem("Port the AI Elements set")
            } footer: {
                ShadcnButton("Approve plan", size: .small) {}
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Confirmation") {
            VStack(spacing: Space.x3) {
                AIConfirmation(
                    message: "Allow **run_tests** to execute `swift test` in this workspace?",
                    state: .approvalRequested
                )
                AIConfirmation(
                    message: "Allow **delete_file** to remove `stale.swift`?",
                    state: .approvalResponded,
                    isApproved: false
                )
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Confirmation — approval scopes") {
            AIConfirmation(
                message: "Allow **run_tests** to execute `swift test` in this workspace?",
                state: .approvalRequested,
                actor: "claude",
                tool: "run_tests",
                reason: "Verifying the port before merge",
                detail: "swift test --filter WorkflowTests",
                onApproveScoped: { _ in },
                // `availableScopes` (0.3.1) — this broker only ever accepts
                // once/session, so `.always` never shows in the dropdown.
                availableScopes: [.once, .session]
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Confirmation — flat decisions") {
            AIConfirmation(
                message: "Allow **run_tests** to execute `swift test` in this workspace?",
                state: .approvalRequested,
                actor: "claude",
                tool: "run_tests",
                onApproveScoped: { _ in },
                availableScopes: [.once, .session, .always],
                presentation: .flatDecisions,
                requestPayloadJSON: "{\"command\": \"swift test\", \"cwd\": \"/Users/jkneen/ShadKit\"}"
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Question form") {
            AIQuestionForm(
                Self.questions,
                selections: $questionSelections,
                writeIns: $questionWriteIns,
                onSubmit: {}
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Queue strip") {
            AIQueueStrip(
                items: queueStripItems,
                onEdit: { _ in },
                onSendNow: { id in queueStripItems.removeAll { $0.id == id } },
                onCancel: { id in queueStripItems.removeAll { $0.id == id } },
                onMove: { _, _ in }
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Todo") {
            AITodoList(todoItems) { id in
                guard let index = todoItems.firstIndex(where: { $0.id == id }) else { return }
                todoItems[index].status = todoItems[index].status.next
            }
            .frame(maxWidth: 620)
        }

        GalleryBlock("Todo — edit/delete/move/assignee, collapsible") {
            AITodoList(
                todoItems,
                onCycle: { id in
                    guard let index = todoItems.firstIndex(where: { $0.id == id }) else { return }
                    todoItems[index].status = todoItems[index].status.next
                },
                onEdit: { _ in },
                onDelete: { id in todoItems.removeAll { $0.id == id } },
                onMove: { id, direction in
                    guard let index = todoItems.firstIndex(where: { $0.id == id }) else { return }
                    let target = direction == .up ? index - 1 : index + 1
                    guard todoItems.indices.contains(target) else { return }
                    todoItems.swapAt(index, target)
                },
                onAssign: { _ in },
                isCollapsible: true
            )
            .frame(maxWidth: 620)
        }

        GalleryBlock("Checkpoint") {
            AICheckpoint(label: "Checkpoint · 14:22", tooltip: "Restore to this point") {}
                .frame(maxWidth: 620)
        }

        GalleryBlock("Queue") {
            AIQueue(sections: [
                (
                    "queued",
                    ShadcnIcon.listTodo,
                    [
                        AIQueueItem(
                            title: "Wire the package into Infinitty",
                            description: "Local path dependency plus a gallery surface"
                        ),
                        AIQueueItem(title: "Screenshot each section", attachments: ["spec.pdf"]),
                    ]
                ),
                (
                    "completed",
                    ShadcnIcon.check,
                    [
                        AIQueueItem(title: "Convert the OKLCH tokens", isCompleted: true),
                        AIQueueItem(title: "Port the primitives", isCompleted: true),
                    ]
                ),
            ])
            .frame(maxWidth: 620)
        }

        GalleryBlock("Context") {
            AIContext(
                usage: AIContextUsage(
                    usedTokens: 128_400,
                    maxTokens: 200_000,
                    inputTokens: 96_200,
                    outputTokens: 24_800,
                    reasoningTokens: 5_400,
                    cachedTokens: 2_000,
                    totalCost: 0.4312
                )
            )
            .padding(.bottom, 220)
        }
    }
}

/// A trivial stand-in for a host's real HTML/SVG preview — a coloured
/// placeholder, never a web view. AIElementsUI never imports WebKit, and
/// neither does this gallery.
private struct GalleryCodeBlockPreviewRenderer: AICodeBlockPreviewRenderer {
    func preview(for source: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            Text("Preview — \(language.uppercased())")
                .font(.system(size: 12, weight: .semibold))
            Text("Host-supplied renderer would draw \(source.count) characters here.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(Space.x3)
        .background(Color.accentColor.opacity(0.08))
    }
}

// MARK: - Helpers

extension View {
    /// Frames a demo in a dashed box so empty states are visible.
    func shadcnBorderedBox() -> some View {
        modifier(GalleryBoxModifier())
    }
}

private struct GalleryBoxModifier: ViewModifier {
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous)
                    .strokeBorder(
                        palette.border,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
    }
}
