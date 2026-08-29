# ShadKit and Titerm Component Reuse Plan

## Synchronized document notice

This document deliberately exists in two places:

- `ShadKit/COMPONENT_REUSE_PLAN.md`
- `titerm/COMPONENT_REUSE_PLAN.md`

The two files describe the same task for both projects. Neither copy is independently canonical. Any change to this plan must update both files in the same task so their contents remain identical.

## Objective

Move broadly reusable assistant UI and interaction contracts from Titerm into ShadKit without moving Titerm's provider, security, persistence, terminal, or application policy into the shared component library.

The largest missing ShadKit capability is a first-class interactive-request layer. Titerm has independently added grouped tool presentation, approval handling, permission controls, richer composer behavior, and run-time interaction UI around ShadKit. Some of those additions are reusable components; others must remain host adapters or product policy.

## Current package boundary

ShadKit currently supplies the reusable UI foundation:

- `ShadcnUI` primitives such as buttons, cards, selects, tabs, inputs, overlays, badges, and collapsible regions.
- `AIElementsUI` models and views such as `AITool`, `UIToolPart`, `UIMessage`, `AIConfirmation`, `AIPlan`, `AIQueue`, `AIContext`, `AIModelSelector`, `AIPromptInput`, and `AIAssistantPanel`.
- `CanvasUI` for canvas-specific presentation.
- `AIElementsGallery` for examples and component demonstrations.

Titerm consumes ShadKit but has added substantial application-local assistant UI in `Sources/InfinittyKit`. The extraction boundary should keep ShadKit provider-neutral and cross-platform wherever practical.

## Component inventory and recommended ownership

| Titerm addition | Proposed ShadKit component or interface | What remains in Titerm |
| --- | --- | --- |
| Grouped, expandable tool calls | `AIToolCallDeck`, `AIToolCallGroup`, and a grouping projection | Provider-specific labels or product overrides |
| Approval cards and decision controls | `AIApprovalRequest`, `AIApprovalDecision`, `AIApprovalCard`, and `AIApprovalDeck` | Approval broker, timeout policy, grants, and provider adapters |
| `AskUserQuestion` rendering | `AIQuestionnaire` with one-to-four question navigation, multi-select, Other, and previews | Claude stream-json mapping and tool-result serialization |
| Composer completion | Generic completion model, ranking/insertion engine, and completion popup | Git, filesystem, and `~/.claude` catalog providers |
| Prompt attachments | Attachment chips, drop target, removal UI, and attachment presentation | Temporary-file spooling and provider upload encoding |
| Grouped queue and read receipts | `AIQueuedPromptGroup` and `AIAgentReceiptStack` | Agent assignment and load-balancing policy |
| Rich message metadata | Attachment, usage, author, and accessory extension points on `AIMessageView` | Titerm-specific identity and token accounting |
| Run status presentation | Data-driven `AIRunStatus` and compact metrics strip | Host lifecycle, provider state, and cost calculation |
| Compact todo drawer | Reusable compact task-list presentation | Assignment rules and transition policy |
| Permission mode picker | Continue composing `ShadcnSelect`; do not add a shallow wrapper | Policy semantics, persistence, and provider launch flags |
| macOS system-permission assistants | Consider a separate macOS-only product only after a second consumer exists | Current Full Disk Access and Screen Recording workflows |
| Collaborative agent cursor | Potential `CanvasUI` component | Product collaboration and transport state |

## Priority 1: grouped tool-call deck

Titerm's `Sources/InfinittyKit/ShadcnToolCallGrouping.swift` is the clearest extraction candidate. It already behaves like a missing ShadKit component:

- Groups raw `[UIToolPart]` values case-insensitively.
- Preserves first appearance and the underlying calls.
- Produces friendly provider names, icons, summaries, and aggregate state.
- Presents nested expandable group and call rows.
- Reuses ShadKit's existing `AIToolInput` and `AIToolOutput` views.
- Depends primarily on `AIElementsUI`, `ShadcnUI`, and SwiftUI.

Proposed public surface:

```swift
public struct AIToolCallGroup: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let icon: String?
    public let tools: [UIToolPart]
    public let state: AIToolState
}

public struct AIToolCallDeck: View {
    public init(
        tools: [UIToolPart],
        labelProvider: @escaping (UIToolPart) -> String
    )
}
```

The grouping rules should have focused unit tests covering order preservation, mixed case, aggregate state, empty input, repeated provider names, and stable identity.

## Priority 2: reusable approval UI

ShadKit's current `AIConfirmation` is limited to a pending state and a Boolean approve-or-deny result. Titerm supports a richer set of authority decisions:

```swift
public enum AIApprovalDecision: Sendable, Equatable {
    case allowOnce
    case allowForSession
    case allowAlways
    case deny
    case cancel
}

public struct AIApprovalRequest: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let tool: UIToolPart?
    public let reason: String?
    public let availableDecisions: [AIApprovalDecision]
}
```

ShadKit should own the typed request, decision vocabulary, and presentation. An `AIApprovalCard` should receive a request and return a selected decision through a callback or response interface. It must not call a global broker or know how a particular provider resumes execution.

Titerm must retain:

- The scoped approval broker and event bus.
- Session grants and expiration behavior.
- Timeout and cancellation policy.
- Fail-closed behavior.
- ACP, Codex, Claude, and Amp protocol adapters.
- Translation between ShadKit decisions and exact provider option identifiers.

## Priority 3: `AskUserQuestion` and multi-question tabs

### Current gap

Titerm's `ClaudeBridge` currently turns every Claude `tool_use` event into a passive `AssistantToolEvent`. `AskUserQuestion` therefore appears as a tool invocation, but there is no typed question request, editable response UI, or response path that sends the matching tool result.

ShadKit has the same structural gap:

- `UIMessagePart` has no approval or question interaction case.
- `AIChatChunk` has no interactive-request event.
- `UIToolPart` only describes tool presentation and execution state.
- `AIChatTransport` has no method for replying to an interactive request.

An interactive tool cannot be represented only as a running tool card. The host must retain the tool-use identifier and return a corresponding result through the provider adapter.

### Verified Claude compatibility

The schema was checked against the locally installed Claude Code 2.1.246 rather than inferred from historical model or tool behavior. Its current `AskUserQuestion` contract supports:

- One to four questions in one request.
- A header of at most 12 characters.
- Two to four options per question.
- Per-question single-select or multi-select behavior.
- Automatic free-form `Other` answers.
- Optional Markdown or HTML preview content for single-select options.
- Multi-select answers encoded as comma-separated values at the Claude tool boundary.

The ShadKit model should preserve more structure than the provider wire format:

```swift
public struct AIUserQuestionRequest: Identifiable, Sendable, Equatable {
    public let id: String
    public let questions: [AIUserQuestion]
}

public struct AIUserQuestion: Identifiable, Sendable, Equatable {
    public let id: String
    public let header: String
    public let question: String
    public let options: [AIUserQuestionOption]
    public let allowsMultipleSelection: Bool
    public let allowsOther: Bool
}

public struct AIUserQuestionOption: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let description: String?
    public let preview: AIQuestionPreview?
}

public enum AIQuestionPreview: Sendable, Equatable {
    case markdown(String)
    case html(String)
}

public enum AIUserQuestionSelection: Sendable, Equatable {
    case options(Set<String>)
    case other(String)
}

public struct AIUserQuestionResponse: Sendable, Equatable {
    public let requestID: String
    public let answers: [String: AIUserQuestionSelection]
}
```

### `AIQuestionnaire` behavior

The shared view should support the full question bundle:

- Omit the tab bar for a single question.
- For two to four questions, render one tab per question using `ShadcnTabs`.
- Use radio-style rows for single-select questions.
- Use checkbox rows for multi-select questions.
- Provide an inline text field or editor for `Other`.
- Mark completed tabs without changing their stable identifiers.
- Provide Back and Next navigation.
- Enable final Submit only when every required question has a valid answer.
- Show preview content only when a selected single-choice option provides it.
- Return one typed `AIUserQuestionResponse` without importing provider or broker code.

Headers are presentation labels and may not be unique. Stable question identifiers must not be derived only from the header. Provider adapters may separately key their wire response by original question text or another provider-required key.

### Claude, Codex, and other adapters

Provider adapters should translate between their wire contracts and the shared ShadKit model:

- Claude can use the full one-to-four question, multi-select, Other, and preview feature set.
- Codex `request_user_input` currently has a narrower contract: up to three questions, two to three options, and no multi-select field.
- Other providers can advertise their own limits and supported features.

Do not reduce the ShadKit component to the lowest common denominator. Instead, define provider capabilities and validate a request before sending it. A host that needs a portable request profile can voluntarily restrict itself to the common subset.

## Shared interaction lifecycle

Approvals and questions need a common lifecycle but must retain separate semantics. A question is not a permission decision, and arbitrary answers must never be interpreted as consent.

```swift
public enum AIInteractionRequest: Identifiable, Sendable, Equatable {
    case approval(AIApprovalRequest)
    case questions(AIUserQuestionRequest)
}

public enum AIInteractionResponse: Sendable, Equatable {
    case approval(AIApprovalDecision)
    case answers(AIUserQuestionResponse)
}

public protocol AIInteractionResponder: Sendable {
    func respond(
        to requestID: String,
        with response: AIInteractionResponse
    ) async throws
}
```

Required runtime changes:

1. Add an interaction representation to `UIMessagePart`, either as one `.interaction` case or distinct `.approval` and `.questions` cases.
2. Add an interactive-request event to `AIChatChunk`.
3. Add a response port to the transport boundary.
4. Preserve pending, submitting, answered, cancelled, expired, and failed states.
5. Prevent duplicate submission with an explicit state transition.
6. Keep the provider tool-use identifier available until the response is acknowledged.
7. Render interaction requests in transcript order rather than in an unrelated global overlay.
8. Allow a host to surface a pending interaction in a secondary deck or status strip without creating a second source of truth.

Titerm's Claude adapter must map `AskUserQuestion` input into `AIUserQuestionRequest`, receive the typed response, serialize the provider-specific answer shape, and send the result associated with the original tool-use identifier. Equivalent ACP, Codex, or OpenCode adapters can be added independently.

## Priority 4: composer completion and attachments

Titerm's composer code currently combines reusable behavior with product-specific sources.

Reusable ShadKit responsibilities:

- Trigger detection.
- Candidate model and stable identity.
- Ranking and filtering.
- Keyboard selection behavior.
- Text replacement and cursor restoration contract.
- Completion popup presentation.
- Attachment chip and removal presentation.
- Drag-and-drop affordance.

Titerm responsibilities:

- Reading `~/.claude` commands or other provider directories.
- Calling Git to discover repository files.
- Project-specific completion catalogs.
- AppKit key interception needed by Titerm's host.
- Spooling images to temporary PNG paths.
- Translating attachments into provider request payloads.

The ShadKit API should accept injected completion sources. It should not scan the filesystem or assume Claude-specific directories.

## Priority 5: queue, receipts, message metadata, and run status

Titerm's `ShadcnAgentReadReceipts`, grouped queued prompts, attachment thumbnails, author avatars, token usage, and run status contain reusable presentation concepts.

Recommended seams:

- `AIAgentReceiptStack`: renders overlapping agent identities from caller-owned data.
- `AIQueuedPromptGroup`: presents a grouped prompt and its participants without assigning work.
- `AIMessageView` accessory slots: author, attachments, footer metadata, usage, and reply context.
- `AIRunStatus`: a data-only phase and status model.
- `AIRunMetricsView`: renders context usage, tokens, duration, or cost supplied by the host.
- A compact task-list style for `AIPlan` or a related model, with caller-owned transition callbacks.

Do not transplant Titerm's entire assistant panel. Its local panel mixes reusable UI with terminal mode, roster state, project switching, provider policy, completion catalogs, attachments, todos, and application lifecycle. Extract the narrow modules and let Titerm continue composing its product shell.

## Permission interface boundary

### Reusable in ShadKit

- Typed approval request and response models.
- Approval card/deck presentation.
- Tool detail rendering inside an approval.
- Loading, submitting, resolved, expired, cancelled, and error states.
- Accessibility labels and keyboard behavior.
- A host-injected response callback or `AIInteractionResponder`.

### Keep in Titerm

- `ask`, `auto`, `always`, and `yolo` semantics.
- App configuration and persistence.
- Session-grant storage and scope identifiers.
- Provider process launch arguments.
- Any option that disables provider safety checks.
- Exact ACP, Codex, Claude, or Amp protocol values.
- Timeouts, cancellation propagation, and fail-closed policy.
- macOS System Settings URLs and app-bundle inspection.

The permission-mode picker is already a composition of `ShadcnSelect`. A named ShadKit wrapper would be shallow and would incorrectly imply common policy semantics. The reusable deep module is the interactive approval lifecycle.

Titerm's Full Disk Access and Screen Recording assistants are AppKit- and bundle-specific. They should stay local unless a second application demonstrates the same requirement. At that point, create a separate macOS-only package product rather than adding them to the cross-platform UI targets.

## Recommended implementation sequence

1. Extract and test `AIToolCallDeck` and its projection.
2. Add typed approval requests, decisions, and reusable approval cards.
3. Add the `AIQuestionnaire` models and tabbed question view.
4. Extend `UIMessagePart`, `AIChatChunk`, and transport interfaces with the interactive-request lifecycle.
5. Implement and fixture-test Titerm's Claude `AskUserQuestion` adapter and response serialization.
6. Add capability validation for Codex and any other provider adapters.
7. Extract the generic composer completion engine and view with injected sources.
8. Extract attachment presentation while retaining host file handling in Titerm.
9. Add grouped queue/read-receipt components and message accessory seams.
10. Add compact, data-driven run status and metrics presentation.

Each extraction should migrate Titerm to the new ShadKit component before its local duplicate is deleted. Tests should cover the public interface at the ShadKit boundary and provider serialization at the Titerm boundary.

## Acceptance criteria

- Both copies of this document remain identical.
- Titerm renders consecutive tool calls through the shared ShadKit tool deck.
- Titerm renders approvals through shared ShadKit UI while retaining its existing broker and provider adapters.
- A Claude `AskUserQuestion` request with multiple questions can be answered completely in Titerm.
- Single-select, multi-select, Other, validation, navigation, cancellation, and duplicate submission are tested.
- The Claude adapter returns a result associated with the original tool-use identifier.
- Codex or other adapters reject unsupported request features clearly rather than silently changing them.
- ShadKit does not import Titerm, provider SDKs, application configuration, Git/process utilities, or macOS permission policy.
- macOS-only system-permission behavior remains outside the cross-platform ShadKit targets.
- Titerm's local duplicate views are removed only after it has migrated to the shared component and equivalent behavior is verified.

## Source map

Relevant Titerm sources include:

- `Sources/InfinittyKit/ShadcnToolCallGrouping.swift`
- `Sources/InfinittyKit/AssistantApproval.swift`
- `Sources/InfinittyKit/ShadcnAssistantHost.swift`
- `Sources/InfinittyKit/ProviderPermissionPolicy.swift`
- `Sources/InfinittyKit/PermissionAssistant.swift`
- `Sources/InfinittyKit/ClaudeBridge.swift`
- `Sources/InfinittyKit/ShadcnTitermAssistantPanel.swift`
- `Sources/InfinittyKit/ComposerCatalog.swift`
- `Sources/InfinittyKit/ComposerCompletion.swift`
- `Sources/InfinittyKit/ComposerCompletionView.swift`
- `Sources/InfinittyKit/ComposerHistory.swift`
- `Sources/InfinittyKit/ShadcnAgentReadReceipts.swift`
- `Sources/InfinittyKit/TitermMessageView.swift`
- `Sources/InfinittyKit/ChatTodoDrawer.swift`

Relevant ShadKit sources include:

- `Sources/AIElementsUI/ChatRuntime.swift`
- `Sources/AIElementsUI/Workflow.swift`
- `Sources/AIElementsUI/AssistantPanel.swift`
- `Sources/AIElementsUI/Message.swift`
- `Sources/AIElementsUI/PromptInput.swift`
- `Sources/ShadcnUI/Primitives/Controls.swift`

## Document maintenance rule

Work on this plan is one cross-project task even though the document is stored in two repositories. Whenever an implementation task changes scope, naming, order, interface decisions, or completion state in this document, that same task must update:

1. `ShadKit/COMPONENT_REUSE_PLAN.md`
2. `titerm/COMPONENT_REUSE_PLAN.md`

Before committing either copy, compare them byte-for-byte. A difference between the files is a documentation defect.
