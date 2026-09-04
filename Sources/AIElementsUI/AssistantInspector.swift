import ShadcnUI
import SwiftUI

/// Ports `right-inspector.tsx`: a resizable side panel with three tabs
/// (Session, Usage, Files), collapsible to a narrow icon rail. Values in,
/// closures out — no git invocation, no transport. The host owns lookup,
/// persistence, and the actual repo actions.
public enum AIInspectorTab: String, CaseIterable, Sendable {
    case session
    case usage
    case files

    public var label: String {
        switch self {
        case .session: "Session"
        case .usage: "Usage"
        case .files: "Files"
        }
    }

    public var systemImage: String {
        switch self {
        case .session: ShadcnIcon.settings2
        case .usage: ShadcnIcon.cpu
        case .files: ShadcnIcon.file
        }
    }
}

/// Which repo action, if any, is currently in flight — drives disabled state
/// and the pulsing icon on its trigger.
public enum AIInspectorOperation: String, Sendable, Equatable {
    case refresh
    case commit
    case push
    case pull
    case suggest
}

/// Read-only usage figures for the Usage tab. Display only — the inspector
/// never computes or reports cost itself.
public struct AIInspectorUsage: Equatable, Sendable {
    public var contextEstimate: Double?
    public var toolCalls: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var cachePercent: Double?
    public var costText: String?

    public init(
        contextEstimate: Double? = nil,
        toolCalls: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cachePercent: Double? = nil,
        costText: String? = nil
    ) {
        self.contextEstimate = contextEstimate
        self.toolCalls = toolCalls
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachePercent = cachePercent
        self.costText = costText
    }
}

/// Session tab values: workspace, session identity, seat count, live state.
public struct AIInspectorSession: Equatable, Sendable {
    public var location: String
    public var sessionReference: String?
    public var seatCount: Int
    public var isLive: Bool

    public init(
        location: String,
        sessionReference: String? = nil,
        seatCount: Int = 0,
        isLive: Bool = false
    ) {
        self.location = location
        self.sessionReference = sessionReference
        self.seatCount = seatCount
        self.isLive = isLive
    }
}

/// Repo state for the Files tab header: folder, branch, ahead/behind.
public struct AIInspectorRepo: Equatable, Sendable {
    public var folder: String?
    public var branch: String?
    public var ahead: Int
    public var behind: Int

    public init(folder: String? = nil, branch: String? = nil, ahead: Int = 0, behind: Int = 0) {
        self.folder = folder
        self.branch = branch
        self.ahead = ahead
        self.behind = behind
    }
}

/// Which sub-view the Files tab is showing: the pending change list, or a
/// directory browser for picking a different file.
public enum AIInspectorFileMode: String, Sendable, Equatable {
    case changes
    case browse
}

/// AI Elements' `Inspector` — Session/Usage/Files tabs behind a resizable,
/// collapsible-to-icon-rail side panel.
public struct AIInspector: View {
    @Binding private var isOpen: Bool
    @Binding private var width: CGFloat
    @Binding private var tab: AIInspectorTab
    @Binding private var commitMessage: String
    @Binding private var branch: String
    private let minWidth: CGFloat
    private let maxWidth: CGFloat

    @State private var dragStartWidth: CGFloat = 0

    private let session: AIInspectorSession
    private let usage: AIInspectorUsage
    private let todos: [AITodoItem]
    private let events: [AIActivityEvent]
    private let changes: [AIActivityFileChange]
    private let repo: AIInspectorRepo
    private let fileMode: AIInspectorFileMode
    private let browse: AIWorkspaceBrowse?
    private let selectedPath: String?
    private let selectedDiff: String?
    private let operation: AIInspectorOperation?

    private let onCycleTodo: (AITodoItem.ID) -> Void
    private let onSetFileMode: (AIInspectorFileMode) -> Void
    private let onSelectFile: (String) -> Void
    private let onBrowse: (String) -> Void
    private let onRefresh: () -> Void
    private let onCommit: (String, String) -> Void
    private let onSuggest: () -> Void
    private let onPush: () -> Void
    private let onPull: () -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        isOpen: Binding<Bool>,
        width: Binding<CGFloat>,
        tab: Binding<AIInspectorTab>,
        commitMessage: Binding<String>,
        branch: Binding<String>,
        minWidth: CGFloat = 240,
        maxWidth: CGFloat = 480,
        session: AIInspectorSession,
        usage: AIInspectorUsage,
        todos: [AITodoItem] = [],
        events: [AIActivityEvent] = [],
        changes: [AIActivityFileChange] = [],
        repo: AIInspectorRepo = AIInspectorRepo(),
        fileMode: AIInspectorFileMode = .changes,
        browse: AIWorkspaceBrowse? = nil,
        selectedPath: String? = nil,
        selectedDiff: String? = nil,
        operation: AIInspectorOperation? = nil,
        onCycleTodo: @escaping (AITodoItem.ID) -> Void = { _ in },
        onSetFileMode: @escaping (AIInspectorFileMode) -> Void = { _ in },
        onSelectFile: @escaping (String) -> Void = { _ in },
        onBrowse: @escaping (String) -> Void = { _ in },
        onRefresh: @escaping () -> Void = {},
        onCommit: @escaping (String, String) -> Void = { _, _ in },
        onSuggest: @escaping () -> Void = {},
        onPush: @escaping () -> Void = {},
        onPull: @escaping () -> Void = {}
    ) {
        self._isOpen = isOpen
        self._width = width
        self._tab = tab
        self._commitMessage = commitMessage
        self._branch = branch
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.session = session
        self.usage = usage
        self.todos = todos
        self.events = events
        self.changes = changes
        self.repo = repo
        self.fileMode = fileMode
        self.browse = browse
        self.selectedPath = selectedPath
        self.selectedDiff = selectedDiff
        self.operation = operation
        self.onCycleTodo = onCycleTodo
        self.onSetFileMode = onSetFileMode
        self.onSelectFile = onSelectFile
        self.onBrowse = onBrowse
        self.onRefresh = onRefresh
        self.onCommit = onCommit
        self.onSuggest = onSuggest
        self.onPush = onPush
        self.onPull = onPull
    }

    public var body: some View {
        Group {
            if isOpen {
                openPane
            } else {
                rail
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            ShadcnTranslucentFill(color: palette.background, cornerRadius: 0)
        )
    }

    // MARK: Open state

    private var openPane: some View {
        VStack(spacing: 0) {
            header
            tabStrip
            ShadcnSeparator()
            ScrollView {
                body(for: tab)
                    .padding(Space.x3)
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .leading) {
            // The doc comment promises "resizable"; this is the drag
            // surface that actually writes `width` — 0.3.0 shipped the
            // binding read-only from the component's side.
            Rectangle()
                .fill(palette.border)
                .frame(width: 4)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragStartWidth == 0 { dragStartWidth = width }
                            let proposed = dragStartWidth - value.translation.width
                            width = min(max(proposed, minWidth), maxWidth)
                        }
                        .onEnded { _ in dragStartWidth = 0 }
                )
                .onTapGesture(count: 2) { width = minWidth }
                .help("Drag to resize · double-click to reset")
                .accessibilityLabel("Resize inspector")
        }
    }

    private var header: some View {
        HStack(spacing: Space.x2) {
            Text("Inspector")
                .font(theme.typography.sans(theme.typography.xs, weight: .semibold))
                .foregroundStyle(palette.mutedForeground)
                .textCase(.uppercase)
            Spacer(minLength: 0)
            ShadcnButton(icon: ShadcnIcon.chevronRight, variant: .ghost, size: .iconXS) {
                isOpen = false
            }
            .accessibilityLabel("Collapse inspector")
            .help("Collapse inspector")
        }
        .padding(.horizontal, Space.x3)
        .padding(.top, Space.x2)
    }

    private var tabStrip: some View {
        HStack(spacing: Space.x1) {
            ForEach(AIInspectorTab.allCases, id: \.self) { candidate in
                Button {
                    tab = candidate
                } label: {
                    HStack(spacing: Space.x1_5) {
                        ShadcnIconView(candidate.systemImage, size: 13)
                        Text(candidate.label)
                    }
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.x1_5)
                    .foregroundStyle(tab == candidate ? palette.foreground : palette.mutedForeground)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                            .fill(tab == candidate ? palette.muted : .clear)
                    )
                }
                .buttonStyle(.shadcnBare)
                .accessibilityLabel(candidate.label)
            }
        }
        .padding(.horizontal, Space.x2)
        .padding(.vertical, Space.x2)
    }

    @ViewBuilder
    private func body(for tab: AIInspectorTab) -> some View {
        switch tab {
        case .session: sessionTab
        case .usage: usageTab
        case .files: filesTab
        }
    }

    // MARK: Session

    private var sessionTab: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            infoRow("Location", session.location)
            if let ref = session.sessionReference {
                infoRow("Session ref", ref, mono: true)
            }
            infoRow("Seats", "\(session.seatCount)")
            infoRow("Live", session.isLive ? "Yes" : "No")

            if !todos.isEmpty {
                AIToolSectionCaption("Todos")
                AITodoList(todos, onCycle: onCycleTodo)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Space.x2) {
            Text(label)
                .font(theme.typography.sans(theme.typography.xs))
                .foregroundStyle(palette.mutedForeground)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(mono ? theme.typography.mono(theme.typography.xs) : theme.typography.sans(theme.typography.xs))
                .foregroundStyle(palette.foreground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: Usage

    private var usageTab: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            if let estimate = usage.contextEstimate {
                infoRow("Context", "\(Int((estimate * 100).rounded()))%")
            }
            infoRow("Tool calls", "\(usage.toolCalls)")
            infoRow("Input", "\(usage.inputTokens)")
            infoRow("Output", "\(usage.outputTokens)")
            if let cache = usage.cachePercent {
                infoRow("Cache", "\(Int((cache * 100).rounded()))%")
            }
            if let costText = usage.costText {
                infoRow("Cost", costText)
            }

            AIActivityPanel(events: events, changes: changes)
        }
    }

    // MARK: Files

    private var filesTab: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            filesHeader

            HStack(spacing: Space.x1) {
                fileModeButton("Changes", mode: .changes)
                fileModeButton("Browse", mode: .browse)
            }

            switch fileMode {
            case .changes: changesList
            case .browse: browseList
            }

            if let selectedDiff {
                AIDiffView(unified: selectedDiff)
            }

            commitForm
        }
    }

    private var filesHeader: some View {
        HStack(spacing: Space.x2) {
            ShadcnIconView(ShadcnIcon.folder, size: 13)
                .foregroundStyle(palette.mutedForeground)
            Text(repo.folder ?? "Files")
                .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                .lineLimit(1)
            if let branch = repo.branch {
                AITaskItemFile(branch, systemImage: ShadcnIcon.gitBranch)
            }
            Spacer(minLength: 0)
            ShadcnButton(icon: ShadcnIcon.arrowDown, variant: .ghost, size: .iconXS) {
                onPull()
            }
            .disabled(operation != nil)
            .accessibilityLabel("Pull latest changes")
            .help("Pull latest changes")

            ShadcnButton(icon: ShadcnIcon.arrowUp, variant: .ghost, size: .iconXS) {
                onPush()
            }
            .disabled(operation != nil)
            .accessibilityLabel("Push changes")
            .help("Push changes")
        }
    }

    private func fileModeButton(_ label: String, mode: AIInspectorFileMode) -> some View {
        ShadcnButton(label, variant: fileMode == mode ? .secondary : .ghost, size: .xs) {
            onSetFileMode(mode)
        }
    }

    private var changesList: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            if changes.isEmpty {
                Text("Nothing to commit")
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
            } else {
                ForEach(changes) { change in
                    Button {
                        onSelectFile(change.path)
                    } label: {
                        HStack(spacing: Space.x2) {
                            ShadcnIconView(ShadcnIcon.file, size: 12)
                            Text(change.path).lineLimit(1)
                            Spacer(minLength: 0)
                            Text("+\(change.additions)").foregroundStyle(AITailwindColor.green600)
                            Text("-\(change.deletions)").foregroundStyle(AITailwindColor.red600)
                        }
                        .font(theme.typography.mono(theme.typography.xs))
                        .foregroundStyle(
                            selectedPath == change.path ? palette.foreground : palette.mutedForeground
                        )
                    }
                    .buttonStyle(.shadcnBare)
                }
            }
        }
    }

    private var browseList: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            if let browse {
                if let parent = browse.parent {
                    Button {
                        onBrowse(parent)
                    } label: {
                        Label("..", systemImage: ShadcnIcon.arrowUp)
                    }
                    .buttonStyle(.shadcnBare)
                    .font(theme.typography.sans(theme.typography.xs))
                }
                ForEach(browse.entries) { entry in
                    Button {
                        entry.isGit ? onSelectFile(entry.path) : onBrowse(entry.path)
                    } label: {
                        Label(entry.name, systemImage: entry.isGit ? ShadcnIcon.gitBranch : ShadcnIcon.folder)
                    }
                    .buttonStyle(.shadcnBare)
                    .font(theme.typography.sans(theme.typography.xs))
                }
            } else {
                Text("No directory loaded")
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
            }
        }
    }

    private var commitForm: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            AIToolSectionCaption("Commit")
            ShadcnTextField("Branch", text: $branch)
                .font(theme.typography.mono(theme.typography.xs))
            ShadcnTextField("What changed, and why", text: $commitMessage)

            HStack(spacing: Space.x2) {
                ShadcnButton("Suggest", systemImage: ShadcnIcon.sparkles, variant: .outline, size: .xs) {
                    onSuggest()
                }
                .disabled(operation != nil)

                ShadcnButton(
                    operation == .commit ? "Committing…" : "Commit",
                    variant: .primary,
                    size: .xs
                ) {
                    onCommit(commitMessage, branch)
                }
                .disabled(operation != nil || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: Icon rail (collapsed)

    private var rail: some View {
        VStack(spacing: Space.x2) {
            ShadcnButton(icon: ShadcnIcon.chevronLeft, variant: .ghost, size: .iconXS) {
                isOpen = true
            }
            .accessibilityLabel("Expand inspector")
            .help("Expand inspector")

            ShadcnSeparator()

            ForEach(AIInspectorTab.allCases, id: \.self) { candidate in
                ShadcnButton(icon: candidate.systemImage, variant: tab == candidate ? .secondary : .ghost, size: .iconXS) {
                    tab = candidate
                    isOpen = true
                }
                .accessibilityLabel(candidate.label)
                .help(candidate.label)
            }
        }
        .padding(.top, Space.x2)
        .frame(width: 40)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .leading) {
            Rectangle().fill(palette.border).frame(width: 1)
        }
    }
}
