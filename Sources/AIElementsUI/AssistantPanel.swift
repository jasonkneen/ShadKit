import ShadcnUI
import SwiftUI

/// Where the reusable assistant top bar is rendered.
public enum AIAssistantPanelTopBarPlacement: Sendable, Equatable {
    case panel
    case external
}

public enum AIAssistantRosterPresentation: Sendable, Equatable {
    case row
    case menu
}

public enum AIAssistantPanelDensity: Sendable, Equatable {
    case standard
    case compact
}

/// Placement and ownership for the panel's reusable chrome.
///
/// `hasExternalNewChatAction` is an ownership signal, not just a visibility
/// preference: when it is true neither the panel header nor the top bar emits
/// another New Chat control.
public struct AIAssistantPanelChrome: Sendable, Equatable {
    public var showsHeader: Bool
    public var hasExternalNewChatAction: Bool
    public var topBarPlacement: AIAssistantPanelTopBarPlacement
    public var rosterPresentation: AIAssistantRosterPresentation
    public var density: AIAssistantPanelDensity

    public init(
        showsHeader: Bool = true,
        hasExternalNewChatAction: Bool = false,
        topBarPlacement: AIAssistantPanelTopBarPlacement = .panel,
        rosterPresentation: AIAssistantRosterPresentation = .row,
        density: AIAssistantPanelDensity = .standard
    ) {
        self.showsHeader = showsHeader
        self.hasExternalNewChatAction = hasExternalNewChatAction
        self.topBarPlacement = topBarPlacement
        self.rosterPresentation = rosterPresentation
        self.density = density
    }
}

enum AIAssistantPanelNewChatOwner: Equatable {
    case header
    case topBar
    case external
}

enum AIAssistantRosterControlKind: Equatable {
    case none
    case single
    case menu
}

/// Stable SwiftUI identity for the stateful conversation surface.
///
/// The stream token is intentionally content-derived and can collide across
/// threads. Keeping thread scope separate ensures `AIConversation` starts with
/// fresh pinning state whenever the active thread changes.
enum AIAssistantConversationIdentity: Hashable, Sendable {
    case unscoped
    case thread(String)
}

extension AIAssistantPanelChrome {
    var newChatOwner: AIAssistantPanelNewChatOwner {
        if hasExternalNewChatAction { return .external }
        return showsHeader ? .header : .topBar
    }

    func rendersRosterRow(rosterCount: Int) -> Bool {
        rosterPresentation == .row && rosterCount > 0
    }

    func topBarRosterControl(rosterCount: Int) -> AIAssistantRosterControlKind {
        guard rosterPresentation == .menu, rosterCount > 0 else { return .none }
        return rosterCount == 1 ? .single : .menu
    }
}

public struct AIAssistantRosterEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let isEnabled: Bool
    /// This agent's context-window usage, 0...1. `nil` when the host has no
    /// telemetry for it yet (e.g. it hasn't taken a turn this session) — the
    /// roster menu omits the meter rather than showing a false 0%.
    public let contextFraction: Double?
    /// True while this agent is actively running a turn — draws the roster
    /// row's pulse indicator.
    public let isWorking: Bool
    /// True when the agent is configured but its provider has no API key —
    /// draws the roster row's missing-key badge instead of silently failing
    /// the next turn.
    public let hasMissingKey: Bool

    public init(
        id: String, name: String, detail: String, isEnabled: Bool = true,
        contextFraction: Double? = nil,
        isWorking: Bool = false,
        hasMissingKey: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isEnabled = isEnabled
        self.contextFraction = contextFraction
        self.isWorking = isWorking
        self.hasMissingKey = hasMissingKey
    }
}

/// One row in the prompt queue.
///
/// A turn can fan out to several agents, so rows carry their own agent label
/// and run state: an unlabelled string alone cannot distinguish the copy that
/// is already running from the copies still waiting behind it.
public struct AIAssistantQueuedItem: Identifiable, Equatable,
                                     ExpressibleByStringLiteral {
    public var id: String
    public var text: String
    /// Which agent this row is addressed to, when the chat has a roster.
    public var agentLabel: String?
    /// True once a backend has this row in flight.
    public var isRunning: Bool
    /// What the running agent is doing right now, e.g. "Bash" or "thinking".
    public var detail: String?

    public init(
        id: String? = nil,
        text: String,
        agentLabel: String? = nil,
        isRunning: Bool = false,
        detail: String? = nil
    ) {
        self.id = id ?? "\(agentLabel ?? "")|\(text)"
        self.text = text
        self.agentLabel = agentLabel
        self.isRunning = isRunning
        self.detail = detail
    }

    public init(stringLiteral value: String) {
        self.init(text: value)
    }
}

@MainActor
public final class AIAssistantPanelModel: ObservableObject {
    @Published public var messages: [UIMessage] = []
    /// The answer currently arriving, rendered as a real assistant turn.
    @Published public var streamingText: String?
    @Published public var isThinking = false
    @Published public var thinkingLabel = "Thinking"
    @Published public var streamingAuthor: String?
    @Published public var roster: [AIAssistantRosterEntry] = []
    /// The highest context-window fraction among roster agents that have
    /// reported one. Highest, not an average: the agent closest to its limit
    /// is the one that actually forces a compaction, and burying that behind
    /// an average would make the indicator read comfortably low right up
    /// until a run fails. `nil` — indicator hidden entirely — until at least
    /// one agent has taken a turn; never a fabricated 0%.
    ///
    /// Public so a host's own status accessory can tell whether the canonical
    /// top-bar indicator is on screen and stand down instead of publishing a
    /// second, differently-scoped percentage beside it.
    public var aggregateContextFraction: Double? {
        roster.compactMap(\.contextFraction).max()
    }
    @Published public var queued: [AIAssistantQueuedItem] = []
    /// Tool calls for the turn in flight.
    ///
    /// Kept apart from `messages` on purpose: hosts rebuild `messages` wholesale
    /// from their own transcript, which would wipe cards folded in there.
    @Published public var tools: [UIToolPart] = []
    @Published public var input = ""
    @Published public var model: String?
    @Published public var effort: String?
    /// Agent/provider choices — Claude, Codex, opencode…
    /// Tuple arrays remain source-compatible; rich options retain brand icons.
    @Published public var agents: [(value: String, label: String)] = []
    @Published public var agentOptions: [ShadcnSelectOption<String>] = []
    @Published public var agent: String?
    /// Concrete models under the selected agent (or all when Auto).
    @Published public var models: [(value: String, label: String)] = []
    @Published public var modelOptions: [ShadcnSelectOption<String>] = []
    @Published public var efforts: [(value: String, label: String)] = []
    @Published public var effortOptions: [ShadcnSelectOption<String>] = []
    /// Settings-owned interface size. The host also scales the complete
    /// ShadKit typography ramp from this value; this copy drives markdown
    /// body text that intentionally sits one point above compact chrome.
    @Published public var messageFontSize: CGFloat = 15
    @Published public var hasFiles = false
    /// Terminal access is explicit and never inferred from attachment.
    @Published public var terminalAvailable = false {
        didSet {
            if !terminalAvailable { terminalAccessEnabled = false }
        }
    }
    @Published public var terminalAccessEnabled = false
    /// Multi-chat switcher rows: `id` is opaque to the panel, `title` is shown.
    @Published public var threads: [ShadcnSelectOption<String>] = []
    @Published public var activeThreadId: String?

    /// Invoked when the user submits. `(request, model, effort)` mirrors the
    /// existing panel's submit signature. The second argument is the selected
    /// **model** id/label (not the agent), matching AppKit's submit path.
    public var onSubmit: ((String, String, String) -> Void)?
    /// Called when the agent or effort picker changes, so a host can apply the
    /// choice to whatever actually owns it. Without these the pickers are
    /// cosmetic.
    public var onAgentChange: ((String) -> Void)?
    public var onModelChange: ((String) -> Void)?
    public var onEffortChange: ((String) -> Void)?
    public var onTerminalAccessChange: ((Bool) -> Void)?
    /// Adds the exact visible model/effort selection to the thread roster.
    public var onAddAgent: ((String, String) -> Void)?
    /// Enables or disables one configured roster entry without removing its state.
    public var onToggleAgent: ((String) -> Void)?
    /// Frees one roster agent's live provider context. The visible transcript
    /// is untouched — only what the provider itself remembers resets.
    public var onCompactContext: ((String) -> Void)?
    /// Same as `onCompactContext`, applied to every roster agent at once.
    public var onCompactAllContext: (() -> Void)?
    /// Roster row reordered by drag — the full new id order, host persists it.
    public var onReorderRoster: (([String]) -> Void)?
    /// Seat menu "Edit" — the host owns the actual editor.
    public var onEditAgent: ((String) -> Void)?
    /// Seat menu "Remove" — drops the agent from the roster entirely,
    /// distinct from `onToggleAgent`'s disable-in-place.
    public var onRemoveAgent: ((String) -> Void)?
    public var onStop: (() -> Void)?
    public var onNewChat: (() -> Void)?
    public var onSelectThread: ((String) -> Void)?
    public var onArchiveThread: ((String) -> Void)?
    public var onForkThread: ((String) -> Void)?
    /// Rich conversation-switcher rows. When empty, `threads` is the fallback.
    @Published public var conversations: [AIConversationEntry] = []

    public init() {}

    /// Fill amount for the single cellular-bars effort glyph.
    /// Auto stays neutral; explicit levels run from no bars to all bars.
    public static func effortSignalValue(for label: String) -> Double {
        let normalized = label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.contains("none") || normalized == "off" { return 0 }
        if normalized.contains("minimal") || normalized == "min" { return 0.15 }
        if normalized.contains("low") { return 0.33 }
        if normalized.contains("medium") || normalized.contains("normal") { return 0.6 }
        if normalized.contains("ultra") || normalized.contains("max") { return 1 }
        if normalized.contains("xhigh") || normalized.contains("extra high") { return 0.9 }
        if normalized.contains("high") { return 0.8 }
        return 0.5
    }

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
            &+ queued.filter(\.isRunning).count
            &+ tools.count
    }

    /// The same signal, split so the conversation can tell a growing live tail
    /// from a structural change and only animate the latter.
    public var conversationToken: AIConversationToken {
        AIConversationToken(
            itemCount: messages.count,
            streamLength: streamingText?.count ?? 0,
            extra: (isThinking ? 1 : 0)
                &+ queued.count
                &+ queued.filter(\.isRunning).count
                &+ tools.count)
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
    ///
    /// The model argument prefers the explicit model pick, then agent, so a
    /// host that only wires agents still routes correctly.
    public func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        let routed = model ?? agent ?? "Auto"
        onSubmit?(text, routed, effort ?? "Auto")
    }

    /// Applies an agent pick the same way the composer select does, including
    /// the host callback. Use this from tests and AppKit bridges so the path
    /// under test is the shipped one.
    public func selectAgent(_ value: String) {
        agent = value
        onAgentChange?(value)
    }

    /// Applies a model pick the same way the composer select does.
    public func selectModel(_ value: String) {
        model = value
        onModelChange?(value)
    }

    /// Applies an effort pick the same way the composer select does.
    public func selectEffort(_ value: String) {
        effort = value
        onEffortChange?(value)
    }

    /// Applies Chat/Terminal mode selection through the host callback. An
    /// unavailable terminal always normalizes back to Chat without invoking a
    /// misleading enable request.
    public func selectTerminalAccess(_ enabled: Bool) {
        guard !enabled || terminalAvailable else {
            terminalAccessEnabled = false
            return
        }
        terminalAccessEnabled = enabled
        onTerminalAccessChange?(enabled)
    }

    public func addSelectedAgent() {
        onAddAgent?(model ?? agent ?? "Auto", effort ?? "Auto")
    }

    public func toggleAgent(_ id: String) {
        onToggleAgent?(id)
    }

    /// Selects a real, different thread and notifies the host exactly once.
    public func selectThread(_ id: String) {
        guard id != activeThreadId, threads.contains(where: { $0.value == id }) else {
            return
        }
        activeThreadId = id
        onSelectThread?(id)
    }

    /// Starts a fresh chat through the model's single semantic callback path.
    public func startNewChat() {
        onNewChat?()
    }
}

/// Pure width split for `AIAssistantPanelThreadAccessoryLayout` — no
/// SwiftUI types, so it's directly unit-testable.
///
/// When both sides' ideal widths fit, each gets its ideal and any surplus
/// goes to the accessory (it sits trailing, so surplus reads as trailing
/// whitespace rather than an awkward gap). When they don't fit, the
/// accessory is guaranteed at least 65% of its own ideal width — matching
/// `AssistantPanelChromeTests`'s pinned expectation for a long run-status
/// string at a narrow bar — or whatever's left after the thread control,
/// whichever is larger; the thread control takes the remainder and only
/// truncates in this branch.
enum AIAssistantPanelThreadAccessoryWidths {
    static func split(
        threadIdeal: CGFloat,
        accessoryIdeal: CGFloat,
        available: CGFloat,
        spacing: CGFloat
    ) -> (thread: CGFloat, accessory: CGFloat) {
        let usable = max(0, available - spacing)
        guard usable > 0 else { return (0, 0) }

        if threadIdeal + accessoryIdeal <= usable {
            let thread = threadIdeal
            let accessory = usable - thread
            return (thread, accessory)
        }

        let accessory = min(
            max(0.65 * accessoryIdeal, usable - threadIdeal),
            usable)
        let thread = usable - accessory
        return (thread, accessory)
    }
}

/// Arranges exactly two subviews — the thread control, then the accessory —
/// per `AIAssistantPanelThreadAccessoryWidths.split`. `layoutPriority`
/// cannot express this rule: it hands a flexible high-priority sibling every
/// remaining pixel before a lower-priority sibling is sized at all, so
/// either the title or the accessory always wins outright regardless of how
/// little the winner actually needs.
struct AIAssistantPanelThreadAccessoryLayout: Layout {
    let spacing: CGFloat
    let threadMaxWidth: CGFloat

    struct Cache {
        var thread: CGFloat = 0
        var accessory: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        // An unconstrained query (a caller asking this container for its own
        // ideal/intrinsic size) must never propose an infinite width to
        // either subview: if a subview hosts something with no intrinsic
        // size of its own (a `GeometryReader`, as the accessory-width probe
        // in `AssistantPanelChromeTests` uses), AppKit's own
        // `intrinsicContentSize` machinery throws on an infinite result.
        // Answer with the sum of each side's own natural width instead.
        guard let proposedWidth = proposal.width, proposedWidth.isFinite else {
            let threadIdeal = min(
                subviews[0].sizeThatFits(Self.unboundedMeasurement).width, threadMaxWidth)
            let accessoryIdeal = subviews[1].sizeThatFits(Self.unboundedMeasurement).width
            let height = max(
                subviews[0].sizeThatFits(
                    ProposedViewSize(width: threadIdeal, height: proposal.height)
                ).height,
                subviews[1].sizeThatFits(
                    ProposedViewSize(width: accessoryIdeal, height: proposal.height)
                ).height)
            return CGSize(width: threadIdeal + spacing + accessoryIdeal, height: height)
        }

        let (thread, accessoryWidth) = widths(
            available: proposedWidth, subviews: subviews, cache: &cache)
        let height = max(
            subviews[0].sizeThatFits(ProposedViewSize(width: thread, height: proposal.height)).height,
            subviews[1].sizeThatFits(ProposedViewSize(width: accessoryWidth, height: proposal.height))
                .height)
        return CGSize(width: min(proposedWidth, thread + spacing + accessoryWidth), height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
    ) {
        guard subviews.count == 2 else { return }
        let (thread, accessoryWidth) = widths(
            available: bounds.width, subviews: subviews, cache: &cache)
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
            proposal: ProposedViewSize(width: thread, height: bounds.height))
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
            proposal: ProposedViewSize(width: accessoryWidth, height: bounds.height))
    }

    /// A caller's accessory content can carry its own `maxWidth: .infinity`
    /// (matching how the top bar itself used to size it), which makes
    /// `sizeThatFits(.unspecified)` propose an unbounded width and — for an
    /// `NSHostingView`-backed subview — crash computing `intrinsicContentSize`
    /// for an infinite size. Proposing a large-but-finite width instead
    /// still yields each subview's true natural (unclamped) size.
    private static let unboundedMeasurement = ProposedViewSize(width: 100_000, height: nil)

    private func widths(
        available rawAvailable: CGFloat, subviews: Subviews, cache: inout Cache
    ) -> (thread: CGFloat, accessory: CGFloat) {
        // Placement always resolves to a concrete, finite bounds, but guard
        // anyway — never let a non-finite width reach the split math or
        // (through it) a subview's proposal.
        let available = rawAvailable.isFinite ? rawAvailable : 0
        let threadIdeal = min(
            subviews[0].sizeThatFits(Self.unboundedMeasurement).width, threadMaxWidth)
        let accessoryIdeal = subviews[1].sizeThatFits(Self.unboundedMeasurement).width
        let result = AIAssistantPanelThreadAccessoryWidths.split(
            threadIdeal: threadIdeal, accessoryIdeal: accessoryIdeal,
            available: available, spacing: spacing)
        cache.thread = result.thread
        cache.accessory = result.accessory
        return result
    }
}

/// Reusable assistant chrome for hosts that place chat controls outside the
/// panel. It remains the canonical implementation even when the panel renders
/// it internally, so thread selection and action ownership cannot drift.
public struct AIAssistantPanelTopBar<Accessory: View>: View {
    @ObservedObject private var model: AIAssistantPanelModel
    private let chrome: AIAssistantPanelChrome
    private let accessory: Accessory

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isRosterMenuPresented = false
    @State private var rosterRowHovering: String?

    public init(
        model: AIAssistantPanelModel,
        chrome: AIAssistantPanelChrome,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.model = model
        self.chrome = chrome
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(spacing: controlSpacing) {
            // `layoutPriority` can't express "the title gets its ideal width
            // unless the accessory actually needs the room": priority tiers
            // hand a flexible high-priority sibling ALL remaining space
            // before a lower-priority one is sized at all, so the accessory
            // (however little it holds) always won at any tier above the
            // title, and the title always won at any tier at or above the
            // accessory. `AIAssistantPanelThreadAccessoryLayout` measures
            // both sides' actual natural widths and only shrinks the title
            // below its ideal when the accessory's ideal genuinely doesn't
            // fit alongside it.
            AIAssistantPanelThreadAccessoryLayout(
                spacing: controlSpacing, threadMaxWidth: threadLabelMaxWidth
            ) {
                threadControl
                    .frame(maxWidth: threadLabelMaxWidth, alignment: .leading)
                accessory
                    .clipped()
            }

            // A top-level `if let` here, not a computed property with its own
            // internal branch: `HStack(spacing:)` allocates a spacing slot for
            // every direct child expression whether or not it renders
            // `EmptyView()`, but it does special-case a literal `if` in its
            // own builder to contribute nothing when the branch is skipped —
            // the same reason `newChatButton` below is written inline rather
            // than through a `chrome.newChatOwner`-branching computed property.
            if chrome.topBarRosterControl(rosterCount: model.roster.count) != .none,
               let aggregate = aggregateContextFraction {
                contextControl(aggregate)
                    .fixedSize(horizontal: true, vertical: false)
            }

            rosterControl
                .fixedSize(horizontal: true, vertical: false)

            if chrome.newChatOwner == .topBar {
                newChatButton
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity)
    }

    private var horizontalPadding: CGFloat {
        chrome.density == .compact ? Space.x2 : Space.x3
    }

    private var verticalPadding: CGFloat {
        chrome.density == .compact ? Space.x1 : Space.x1_5
    }

    private var controlSpacing: CGFloat {
        chrome.density == .compact ? Space.x1 : Space.x2
    }

    private var threadLabelMaxWidth: CGFloat {
        chrome.density == .compact ? 180 : 480
    }

    private var activeThreadLabel: String {
        if let activeThreadId = model.activeThreadId,
           let active = model.threads.first(where: { $0.value == activeThreadId }) {
            return active.label
        }
        return model.threads.count == 1 ? (model.threads.first?.label ?? "New chat") : "Chat"
    }

    @ViewBuilder
    private var threadControl: some View {
        // AppKit NSMenu, rebuilt from `model.threads` on every update.
        // SwiftUI `Menu { ForEach }` inside the hosted Chat pane captured an
        // empty list on first render and never showed restored conversations.
        conversationMenuChrome {
            #if canImport(AppKit)
            AIConversationMenu(
                threads: model.conversations.isEmpty
                    ? model.threads.map {
                        AIConversationEntry(
                            id: $0.value, title: $0.label, updatedAt: Date())
                    }
                    : model.conversations,
                activeId: model.activeThreadId,
                compact: chrome.density == .compact,
                onSelect: { model.selectThread($0) },
                onNew: { model.startNewChat() },
                onArchive: model.onArchiveThread,
                onFork: model.onForkThread)
            #else
            Menu {
                ForEach(model.threads) { thread in
                    Button {
                        model.selectThread(thread.value)
                    } label: {
                        if thread.value == model.activeThreadId {
                            Label(thread.label, systemImage: "checkmark")
                        } else {
                            Text(thread.label)
                        }
                    }
                }
                if !model.threads.isEmpty { Divider() }
                Button("New chat") { model.startNewChat() }
            } label: {
                HStack(spacing: Space.x1) {
                    Text(activeThreadLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    ShadcnIconView(ShadcnIcon.chevronDown, size: 10)
                        .foregroundStyle(palette.mutedForeground)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            #endif
        }
        .accessibilityLabel("Chat: \(activeThreadLabel)")
        .accessibilityHint("Choose a chat or start a new one")
        .shadcnTooltip(activeThreadLabel)
    }

    private func conversationMenuChrome<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, Space.x2)
            .frame(height: chrome.density == .compact ? 24 : 28)
            .frame(
                minWidth: 72,
                maxWidth: threadLabelMaxWidth,
                alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                    .fill(palette.isDark ? palette.input.opacity(0.3) : palette.background)
            )
            .shadcnBorder(palette.input, cornerRadius: theme.radius.md)
    }

    /// One number for "how close is this conversation to running out of
    /// room", plus — on hover — the real per-agent breakdown it was built
    /// from. Distinct from the roster menu's own per-row meters: this is the
    /// thing visible without opening anything, so a multi-agent Chat has one
    /// trustworthy answer instead of five different agents each showing their
    /// own private number (or nothing, silently).
    /// Takes the fraction as a parameter rather than re-deriving it: the
    /// caller in `body` has already unwrapped it to decide whether to
    /// contribute an `HStack` spacing slot at all (see the comment there),
    /// and a second `if let` here would let the two disagree.
    private func contextControl(_ aggregate: Double) -> some View {
        HStack(spacing: Space.x1) {
            AIContextGauge(fraction: aggregate)
            Text(aggregate.formatted(.percent.precision(.fractionLength(0))))
                .font(theme.typography.sans(theme.typography.xs))
                .foregroundStyle(palette.mutedForeground)
        }
        .padding(.horizontal, Space.x2)
        .frame(height: chrome.density == .compact ? 24 : 28)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.isDark ? palette.input.opacity(0.3) : palette.background)
        )
        .shadcnBorder(palette.input, cornerRadius: theme.radius.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Context usage across agents")
        .accessibilityValue(contextAccessibilityValue)
        .shadcnHoverOverlay(width: 288, alignment: .trailing) {
            contextPopoutContent
        }
    }

    private var aggregateContextFraction: Double? {
        model.aggregateContextFraction
    }

    private var contextAccessibilityValue: String {
        let reporting = model.roster.filter { $0.contextFraction != nil }.count
        let percent = Int((aggregateContextFraction ?? 0) * 100)
        return "\(percent) percent, highest of \(reporting) of "
            + "\(model.roster.count) agents reporting"
    }

    private var contextPopoutContent: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(spacing: Space.x2) {
                ShadcnMenuLabel("Context by agent")
                Spacer(minLength: Space.x2)
                if model.onCompactAllContext != nil {
                    ShadcnButton(
                        "Compact all", systemImage: ShadcnIcon.refresh,
                        variant: .ghost, size: .xs
                    ) {
                        model.onCompactAllContext?()
                    }
                    .accessibilityHint(
                        "Frees every agent's live context; the transcript stays"
                    )
                }
            }
            .padding(.horizontal, Space.x2)
            ForEach(model.roster) { agent in
                contextPopoutRow(agent)
            }
        }
    }

    private func contextPopoutRow(_ agent: AIAssistantRosterEntry) -> some View {
        HStack(spacing: Space.x2) {
            Text("@\(agent.name)")
                .font(theme.typography.sans(theme.typography.sm))
                .lineLimit(1)
            Spacer(minLength: Space.x2)
            if let fraction = agent.contextFraction {
                AIContextGauge(fraction: fraction)
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
                    .frame(minWidth: 34, alignment: .trailing)
                if model.onCompactContext != nil {
                    ShadcnButton(
                        "Compact", systemImage: ShadcnIcon.refresh,
                        variant: .ghost, size: .xs
                    ) {
                        model.onCompactContext?(agent.id)
                    }
                    .accessibilityHint(
                        "Frees this agent's live context; the transcript stays"
                    )
                }
            } else {
                Text("No data yet")
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
            }
        }
        .padding(.horizontal, Space.x2)
        .padding(.vertical, Space.x1)
    }

    @ViewBuilder
    private var rosterControl: some View {
        switch chrome.topBarRosterControl(rosterCount: model.roster.count) {
        case .none:
            EmptyView()
        case .single:
            if let agent = model.roster.first {
                rosterChip(agent)
            }
        case .menu:
            rosterMenu
        }
    }

    private func rosterChip(_ agent: AIAssistantRosterEntry) -> some View {
        ShadcnButton(
            "@\(agent.name)",
            variant: agent.isEnabled ? .secondary : .outline,
            size: .xs
        ) {
            model.toggleAgent(agent.id)
        }
        .opacity(agent.isEnabled ? 1 : 0.55)
        .help(
            agent.isEnabled
                ? "\(agent.detail) — click to disable"
                : "\(agent.detail) — disabled; click to re-enable"
        )
        .accessibilityLabel(
            "\(agent.name), \(agent.isEnabled ? "enabled" : "disabled")"
        )
        .accessibilityHint(agent.isEnabled ? "Disable agent" : "Re-enable agent")
    }

    private var rosterMenu: some View {
        let enabledCount = model.roster.lazy.filter(\.isEnabled).count
        return ShadcnDropdownMenu(
            isPresented: $isRosterMenuPresented,
            minWidth: 220,
            alignment: .trailing
        ) {
            ShadcnButton(
                "\(enabledCount)/\(model.roster.count)",
                systemImage: ShadcnIcon.sparkles,
                variant: .secondary,
                size: .xs
            ) {
                isRosterMenuPresented.toggle()
            }
            .accessibilityLabel(
                "Agents, \(enabledCount) of \(model.roster.count) enabled"
            )
            .accessibilityHint("Show agents")
            .shadcnTooltip("Agents")
        } content: {
            VStack(spacing: 0) {
                ShadcnMenuLabel("Agents")
                ForEach(model.roster) { agent in
                    rosterMenuRow(agent)
                }
            }
        }
    }

    /// `ShadcnMenuItem` has no trailing-accessory slot, and it is a stock
    /// primitive other menus rely on staying plain — so the context meter
    /// gets a local row here instead of a change to that shared component.
    private func rosterMenuRow(_ agent: AIAssistantRosterEntry) -> some View {
        Button {
            model.toggleAgent(agent.id)
            isRosterMenuPresented = false
        } label: {
            HStack(spacing: Space.x2) {
                Text("@\(agent.name) · \(agent.detail)")
                    .lineLimit(1)
                Spacer(minLength: Space.x4)
                if let fraction = agent.contextFraction {
                    AIContextGauge(fraction: fraction)
                    Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                        .font(theme.typography.sans(theme.typography.xs))
                        .foregroundStyle(palette.mutedForeground)
                }
                if agent.isEnabled {
                    ShadcnIconView(ShadcnIcon.check, size: 16)
                }
            }
            .font(theme.typography.sans(theme.typography.sm))
            .foregroundStyle(rosterRowHovering == agent.id ? palette.accentForeground : palette.popoverForeground)
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x1_5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.sm, style: .continuous)
                    .fill(rosterRowHovering == agent.id ? palette.accent : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.shadcnBare)
        .onHover { rosterRowHovering = $0 ? agent.id : nil }
        .accessibilityLabel(
            "\(agent.name), \(agent.isEnabled ? "enabled" : "disabled")"
        )
        .accessibilityHint(agent.isEnabled ? "Disable agent" : "Re-enable agent")
    }

    private var newChatButton: some View {
        ShadcnButton(
            icon: ShadcnIcon.plus,
            variant: .ghost,
            size: chrome.density == .compact ? .iconXS : .iconSM
        ) {
            model.startNewChat()
        }
        .shadcnTooltip("New chat")
        .accessibilityLabel("New chat")
    }
}

extension AIAssistantPanelTopBar where Accessory == EmptyView {
    public init(
        model: AIAssistantPanelModel,
        chrome: AIAssistantPanelChrome
    ) {
        self.init(model: model, chrome: chrome) { EmptyView() }
    }
}

/// A complete assistant surface: transcript, queue and composer.
///
/// This is the whole panel, not just the transcript — the composer, model and
/// effort pickers are ShadKit too, so an embedding app gets one coherent
/// surface rather than SwiftUI content inside a foreign frame.
///
/// State is driven from outside (`AIAssistantPanelModel`) so an AppKit host can
/// keep feeding it exactly as it fed the view it replaces.
/// View-builder slots an `AIAssistantPanel` host can fill without owning the
/// panel's layout. Every slot is optional and type-erased so this stays a
/// plain value the panel can default and store.
public struct AIAssistantPanelDeckSlots {
    public var aboveTranscript: (() -> AnyView)?
    public var belowTranscript: (() -> AnyView)?
    public var aboveComposer: (() -> AnyView)?
    /// Rendered as extra `AIMessageActions` entries for each transcript row.
    public var messageAccessory: ((UIMessage) -> AnyView)?

    public init(
        aboveTranscript: (() -> AnyView)? = nil,
        belowTranscript: (() -> AnyView)? = nil,
        aboveComposer: (() -> AnyView)? = nil,
        messageAccessory: ((UIMessage) -> AnyView)? = nil
    ) {
        self.aboveTranscript = aboveTranscript
        self.belowTranscript = belowTranscript
        self.aboveComposer = aboveComposer
        self.messageAccessory = messageAccessory
    }

    public static var none: AIAssistantPanelDeckSlots { AIAssistantPanelDeckSlots() }
}

public struct AIAssistantPanel: View {
    @ObservedObject private var model: AIAssistantPanelModel
    let chrome: AIAssistantPanelChrome
    let deckSlots: AIAssistantPanelDeckSlots

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnSurfaceOpacity) private var surfaceOpacity
    @Environment(\.shadcnTheme) private var theme

    public init(
        model: AIAssistantPanelModel,
        showsHeader: Bool = true,
        deckSlots: AIAssistantPanelDeckSlots = .none
    ) {
        self.model = model
        self.chrome = AIAssistantPanelChrome(
            showsHeader: showsHeader,
            hasExternalNewChatAction: false,
            topBarPlacement: .panel,
            rosterPresentation: .row,
            density: .standard
        )
        self.deckSlots = deckSlots
    }

    public init(
        model: AIAssistantPanelModel,
        chrome: AIAssistantPanelChrome,
        deckSlots: AIAssistantPanelDeckSlots = .none
    ) {
        self.model = model
        self.chrome = chrome
        self.deckSlots = deckSlots
    }

    var rendersTopBar: Bool {
        chrome.topBarPlacement == .panel
    }

    var rendersTopBarSeparator: Bool {
        rendersTopBar
    }

    var conversationStyle: AIConversationStyle {
        chrome.density == .compact ? .compact : .standard
    }

    var messageStyle: AIMessageStyle {
        chrome.density == .compact ? .compact : .standard
    }

    var conversationIdentity: AIAssistantConversationIdentity {
        guard let activeThreadId = model.activeThreadId else { return .unscoped }
        return .thread(activeThreadId)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if chrome.showsHeader {
                header
                ShadcnSeparator()
            }

            if rendersTopBar {
                AIAssistantPanelTopBar(model: model, chrome: chrome)
                if rendersTopBarSeparator {
                    ShadcnSeparator()
                }
            }

            if chrome.rendersRosterRow(rosterCount: model.roster.count) {
                rosterBar
                ShadcnSeparator()
            }

            deckSlots.aboveTranscript?()

            transcript
                .environment(\.aiMessageTextSize, model.messageFontSize)
                .aiMessageStyle(messageStyle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)

            deckSlots.belowTranscript?()

            if !model.queued.isEmpty {
                queue
            }

            deckSlots.aboveComposer?()

            // Keep the composer fully visible — never let the transcript's
            // flexible height shove chips under a clipped bottom edge (popover
            // + rounded hosts were cutting the footer mid-row).
            composer
                .padding(
                    .horizontal,
                    chrome.density == .compact ? Space.x2 : Space.x3
                )
                .padding(
                    .top,
                    chrome.density == .compact ? Space.x2 : Space.x3
                )
                .padding(
                    .bottom,
                    chrome.density == .compact ? Space.x3 : Space.x4
                )
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.opacity(surfaceOpacity))
        .onAppear(perform: applyComposerQAHooks)
    }

    /// `SHADCN_COMPOSER_SELECT_AGENT=Claude` (etc.) applies a selection on
    /// appear so a screenshot pass can prove the host callback path without
    /// depending on CGEvent hit-testing of a transient menu.
    private func applyComposerQAHooks() {
        if let name = ProcessInfo.processInfo.environment["SHADCN_COMPOSER_SELECT_AGENT"],
           !name.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                model.selectAgent(name)
            }
        }
        if let name = ProcessInfo.processInfo.environment["SHADCN_COMPOSER_SELECT_MODEL"],
           !name.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                model.selectModel(name)
            }
        }
        if let name = ProcessInfo.processInfo.environment["SHADCN_COMPOSER_SELECT_EFFORT"],
           !name.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                model.selectEffort(name)
            }
        }
        if let typed = ProcessInfo.processInfo.environment["SHADCN_COMPOSER_TYPE"],
           !typed.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                model.input = typed
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Space.x2) {
            ShadcnIconView(ShadcnIcon.sparkles, size: 14)
                .foregroundStyle(palette.mutedForeground)
            Text("Chat")
                .font(theme.typography.sans(theme.typography.sm, weight: .medium))
            Spacer()
            if chrome.newChatOwner == .header {
                ShadcnButton(icon: ShadcnIcon.plus, variant: .ghost, size: .iconSM) {
                    model.startNewChat()
                }
                .offset(x: 3, y: 4)
                .shadcnTooltip("New chat")
                .accessibilityLabel("New chat")
            }
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x2)
    }

    private var rosterBar: some View {
        AIAssistantRosterRail(
            entries: model.roster,
            density: chrome.density,
            onToggle: { model.toggleAgent($0) },
            onReorder: model.onReorderRoster,
            onEdit: model.onEditAgent,
            onRemove: model.onRemoveAgent
        )
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
            AIConversation(
                token: model.conversationToken,
                style: conversationStyle
            ) {
                ForEach(model.messages) { message in
                    AIMessageView(
                        message: message,
                        onCopy: { copy($0.text) },
                        usesAgentBubble: model.roster.count > 1,
                        accessoryActions: deckSlots.messageAccessory.map { fn in
                            { fn(message) }
                        })
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
                        message: UIMessage(
                            id: "in-flight", role: .assistant, text: streaming,
                            author: model.streamingAuthor),
                        usesAgentBubble: model.roster.count > 1)
                    // In-flight message has no stable identity for
                    // messageAccessory yet; skip the slot for this row.
                } else if model.isThinking {
                    AIMessage(.assistant) {
                        HStack(spacing: Space.x2) {
                            AILoader(size: 14)
                            AIShimmer(model.thinkingLabel, duration: 1.2)
                        }
                    }
                }
            }
            .id(conversationIdentity)
        }
    }

    // MARK: Queue

    private var queue: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            ForEach(Array(model.queued.enumerated()), id: \.offset) { _, item in
                HStack(spacing: Space.x2) {
                    if item.isRunning {
                        AILoader(size: 10)
                            .foregroundStyle(palette.primary)
                    } else {
                        Circle()
                            .strokeBorder(
                                palette.mutedForeground.opacity(0.5), lineWidth: 1)
                            .frame(width: 8, height: 8)
                    }
                    if let agentLabel = item.agentLabel {
                        Text(agentLabel)
                            .font(theme.typography.sans(theme.typography.xs))
                            .foregroundStyle(
                                item.isRunning
                                    ? palette.foreground : palette.mutedForeground)
                    }
                    Text(item.detail ?? (item.isRunning ? "running" : "queued"))
                        .font(theme.typography.mono(theme.typography.xs))
                        .foregroundStyle(palette.mutedForeground.opacity(0.8))
                    Text(item.text)
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

    /// Binding that writes through to the host callback. A plain `$model.agent`
    /// left the pickers cosmetic — the value changed in the model but
    /// `onAgentChange` never ran.
    private var agentSelection: Binding<String?> {
        Binding(
            get: { model.agent },
            set: { newValue in
                model.agent = newValue
                if let newValue { model.onAgentChange?(newValue) }
            }
        )
    }

    private var modelSelection: Binding<String?> {
        Binding(
            get: { model.model },
            set: { newValue in
                model.model = newValue
                if let newValue { model.onModelChange?(newValue) }
            }
        )
    }

    private var effortSelection: Binding<String?> {
        Binding(
            get: { model.effort },
            set: { newValue in
                model.effort = newValue
                if let newValue { model.onEffortChange?(newValue) }
            }
        )
    }

    private var visibleAgentOptions: [ShadcnSelectOption<String>] {
        model.agentOptions.isEmpty
            ? model.agents.map { ShadcnSelectOption(value: $0.value, label: $0.label) }
            : model.agentOptions
    }

    private var visibleModelOptions: [ShadcnSelectOption<String>] {
        model.modelOptions.isEmpty
            ? model.models.map { ShadcnSelectOption(value: $0.value, label: $0.label) }
            : model.modelOptions
    }

    private var visibleEffortOptions: [ShadcnSelectOption<String>] {
        let source = model.effortOptions.isEmpty
            ? model.efforts.map {
                ShadcnSelectOption(value: $0.value, label: $0.label)
            }
            : model.effortOptions
        return source.map {
            ShadcnSelectOption(
                value: $0.value,
                label: $0.label,
                systemImage: ShadcnIcon.cellularBars,
                symbolVariableValue: AIAssistantPanelModel.effortSignalValue(for: $0.label)
            )
        }
    }

    /// QA: `SHADCN_COMPOSER_OPEN_SELECT=agent|model|effort` opens that picker
    /// on appear so a screenshot pass can prove upward placement.
    private var composerOpenSelect: String? {
        ProcessInfo.processInfo.environment["SHADCN_COMPOSER_OPEN_SELECT"]
    }

    private var modeControl: some View {
        HStack(spacing: 0) {
            ShadcnButton(
                icon: ShadcnIcon.chat,
                variant: model.terminalAccessEnabled ? .ghost : .secondary,
                size: .iconXS
            ) {
                model.selectTerminalAccess(false)
            }
            .accessibilityLabel("Chat mode")
            .accessibilityAddTraits(
                model.terminalAccessEnabled ? [] : .isSelected
            )
            .accessibilityHint("Use workspace coding tools without controlling a terminal")
            .shadcnTooltip("Chat mode")

            ShadcnButton(
                icon: ShadcnIcon.terminal,
                variant: model.terminalAccessEnabled ? .secondary : .ghost,
                size: .iconXS
            ) {
                model.selectTerminalAccess(true)
            }
            .disabled(!model.terminalAvailable)
            .accessibilityLabel("Terminal mode")
            .accessibilityAddTraits(
                model.terminalAccessEnabled ? .isSelected : []
            )
            .accessibilityHint(
                model.terminalAvailable
                    ? "Allow this Chat to control the attached visible terminal"
                    : "No terminal is attached")
            .shadcnTooltip(
                model.terminalAvailable ? "Terminal mode" : "No terminal attached")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.muted.opacity(0.55))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chat execution mode")
        .accessibilityValue(model.terminalAccessEnabled ? "Terminal" : "Chat")
    }

    private var composerStyle: AIPromptInputStyle {
        var style = AIPromptInputStyle.compact
        // Keep the first line clear of the Chat/Terminal controls floating in
        // the prompt's top-right corner.
        style.textFieldTrailingAccessoryWidth = 64
        return style
    }

    private var composer: some View {
        AIPromptInput(
            text: $model.input,
            placeholder: "Ask anything",
            status: model.status,
            // A sidebar composer rests at one line; `min-h-16` reads as a big
            // empty box that visibly shrinks once content arrives.
            style: composerStyle,
            onSubmit: { model.submit() },
            onStop: { model.onStop?() }
        ) {
            HStack(spacing: Space.x1) {
                if model.hasFiles {
                    AIPromptInputButton(
                        systemImage: ShadcnIcon.paperclip, tooltip: "Files") {}
                }
                if !visibleAgentOptions.isEmpty {
                    ShadcnSelect(
                        "Provider", selection: agentSelection,
                        startsOpen: composerOpenSelect == "agent",
                        isCompact: true, triggerStyle: .iconOnly,
                        edge: .top, options: visibleAgentOptions)
                }
                if !visibleModelOptions.isEmpty {
                    ShadcnSelect(
                        "Model", selection: modelSelection,
                        startsOpen: composerOpenSelect == "model",
                        isCompact: true, triggerStyle: .labelOnly,
                        edge: .top, maxVisibleRows: 10,
                        options: visibleModelOptions)
                }
                if !visibleEffortOptions.isEmpty {
                    ShadcnSelect(
                        "Thinking", selection: effortSelection,
                        startsOpen: composerOpenSelect == "effort",
                        isCompact: true, triggerStyle: .symbolOnly,
                        edge: .top, options: visibleEffortOptions)
                }
                ShadcnButton(
                    icon: ShadcnIcon.plus, variant: .ghost, size: .iconXS
                ) {
                    model.addSelectedAgent()
                }
                .disabled(model.model == nil && model.agent == nil)
                .accessibilityLabel("Add selected agent")
                .shadcnTooltip("Add selected agent")
            }
        }
        .overlay(alignment: .topTrailing) {
            modeControl
                .padding(.top, Space.x2)
                .padding(.trailing, Space.x2)
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

/// Reusable seat rail: the same horizontal roster strip ``AIAssistantPanel``
/// docks under its top bar, extracted so other shells (e.g. ``AIChatbot``)
/// can compose it directly. Values in, closures out — no model dependency.
public struct AIAssistantRosterRail: View {
    private let entries: [AIAssistantRosterEntry]
    private let density: AIAssistantPanelDensity
    private let onToggle: (String) -> Void
    private let onReorder: (([String]) -> Void)?
    private let onEdit: ((String) -> Void)?
    private let onRemove: ((String) -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        entries: [AIAssistantRosterEntry],
        density: AIAssistantPanelDensity = .standard,
        onToggle: @escaping (String) -> Void = { _ in },
        onReorder: (([String]) -> Void)? = nil,
        onEdit: ((String) -> Void)? = nil,
        onRemove: ((String) -> Void)? = nil
    ) {
        self.entries = entries
        self.density = density
        self.onToggle = onToggle
        self.onReorder = onReorder
        self.onEdit = onEdit
        self.onRemove = onRemove
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.x2) {
                Text("Agents")
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .foregroundStyle(palette.mutedForeground)
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, agent in
                    seat(agent, index: index)
                }
            }
            .padding(.horizontal, density == .compact ? Space.x2 : Space.x3)
            .padding(.vertical, density == .compact ? Space.x1 : Space.x1_5)
        }
    }

    private func seat(_ agent: AIAssistantRosterEntry, index: Int) -> some View {
        ShadcnButton(
            "@\(agent.name)",
            variant: agent.isEnabled ? .secondary : .outline,
            size: .xs
        ) {
            onToggle(agent.id)
        }
        .opacity(agent.isEnabled ? 1 : 0.55)
        .overlay(alignment: .topTrailing) {
            if agent.isWorking {
                AILoader(size: 8)
                    .foregroundStyle(palette.primary)
                    .offset(x: 4, y: -4)
                    .accessibilityLabel("Working")
            } else if agent.hasMissingKey {
                ShadcnIconView(ShadcnIcon.alertTriangle, size: 10)
                    .foregroundStyle(palette.destructive)
                    .offset(x: 4, y: -4)
                    .accessibilityLabel("Missing API key")
            }
        }
        .help(
            agent.hasMissingKey
                ? "\(agent.detail) — missing API key"
                : agent.isEnabled
                    ? "\(agent.detail) — click to disable"
                    : "\(agent.detail) — disabled; click to re-enable")
        .accessibilityLabel(
            "\(agent.name), \(agent.isEnabled ? "enabled" : "disabled")"
                + (agent.isWorking ? ", working" : "")
                + (agent.hasMissingKey ? ", missing API key" : ""))
        .contextMenu {
            if index > 0, let onReorder {
                Button("Move earlier") { move(agent.id, to: index - 1, onReorder) }
            }
            if index < entries.count - 1, let onReorder {
                Button("Move later") { move(agent.id, to: index + 1, onReorder) }
            }
            if let onEdit {
                Button("Edit…") { onEdit(agent.id) }
            }
            if let onRemove {
                Button("Remove", role: .destructive) { onRemove(agent.id) }
            }
        }
    }

    private func move(_ id: String, to newIndex: Int, _ onReorder: ([String]) -> Void) {
        var order = entries.map(\.id)
        guard let currentIndex = order.firstIndex(of: id),
              order.indices.contains(newIndex) else { return }
        order.swapAt(currentIndex, newIndex)
        onReorder(order)
    }
}
