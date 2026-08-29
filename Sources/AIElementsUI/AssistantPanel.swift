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

    public init(
        id: String, name: String, detail: String, isEnabled: Bool = true,
        contextFraction: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isEnabled = isEnabled
        self.contextFraction = contextFraction
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
            threadControl
                .frame(
                    minWidth: 0,
                    maxWidth: threadLabelMaxWidth,
                    alignment: .leading
                )
                .layoutPriority(0)

            accessory
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                .clipped()
                .layoutPriority(1)

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
        chrome.density == .compact ? 180 : 240
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
public struct AIAssistantPanel: View {
    @ObservedObject private var model: AIAssistantPanelModel
    let chrome: AIAssistantPanelChrome

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(model: AIAssistantPanelModel, showsHeader: Bool = true) {
        self.model = model
        self.chrome = AIAssistantPanelChrome(
            showsHeader: showsHeader,
            hasExternalNewChatAction: false,
            topBarPlacement: .panel,
            rosterPresentation: .row,
            density: .standard
        )
    }

    public init(
        model: AIAssistantPanelModel,
        chrome: AIAssistantPanelChrome
    ) {
        self.model = model
        self.chrome = chrome
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

            transcript
                .environment(\.aiMessageTextSize, model.messageFontSize)
                .aiMessageStyle(messageStyle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)

            if !model.queued.isEmpty {
                queue
            }

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
        .background(palette.background)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.x2) {
                Text("Agents")
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .foregroundStyle(palette.mutedForeground)
                ForEach(model.roster) { agent in
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
                            : "\(agent.detail) — disabled; click to re-enable")
                    .accessibilityLabel(
                        "\(agent.name), \(agent.isEnabled ? "enabled" : "disabled")")
                }
            }
            .padding(
                .horizontal,
                chrome.density == .compact ? Space.x2 : Space.x3
            )
            .padding(
                .vertical,
                chrome.density == .compact ? Space.x1 : Space.x1_5
            )
        }
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
                streamToken: model.streamToken,
                style: conversationStyle
            ) {
                ForEach(model.messages) { message in
                    AIMessageView(
                        message: message,
                        onCopy: { copy($0.text) },
                        usesAgentBubble: model.roster.count > 1)
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
