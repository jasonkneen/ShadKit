import ShadcnUI
import SwiftUI

/// AI Elements' `Task` — a magnifier-headed collapsible whose contents hang off
/// a `border-l-2 border-muted` rail.
public struct AITask<Content: View>: View {
    private let title: String
    private let defaultOpen: Bool
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        title: String,
        defaultOpen: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.defaultOpen = defaultOpen
        self.content = content()
    }

    public var body: some View {
        ShadcnDisclosure(defaultOpen: defaultOpen, spacing: Space.x4) { isOpen in
            HStack(spacing: Space.x2) {
                ShadcnIconView(ShadcnIcon.search, size: 16)
                Text(title)
                    .font(theme.typography.sans(theme.typography.sm))
                ShadcnDisclosureChevron(isOpen: isOpen)
                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.mutedForeground)
            .contentShape(Rectangle())
        } content: {
            HStack(alignment: .top, spacing: Space.x4) {
                Rectangle()
                    .fill(palette.muted)
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: Space.x2) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Todo

/// Lifecycle of one ``AITodoItem`` row. Tapping a row cycles it forward:
/// pending → in progress → completed → pending.
public enum AITodoStatus: String, Sendable, CaseIterable {
    case pending
    case inProgress = "in-progress"
    case completed

    /// The state a tap on this row moves to next.
    public var next: AITodoStatus {
        switch self {
        case .pending: .inProgress
        case .inProgress: .completed
        case .completed: .pending
        }
    }

    public var systemImage: String {
        switch self {
        case .pending: ShadcnIcon.circle
        case .inProgress: ShadcnIcon.clock
        case .completed: ShadcnIcon.checkCircle
        }
    }

    public var iconTint: Color? {
        switch self {
        case .pending: nil
        case .inProgress: AITailwindColor.blue600
        case .completed: AITailwindColor.green600
        }
    }
}

/// One row of an ``AITodoList``.
public struct AITodoItem: Identifiable, Sendable {
    public let id: String
    public var title: String
    public var status: AITodoStatus
    public var actor: String?
    public var tags: [String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        status: AITodoStatus = .pending,
        actor: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.actor = actor
        self.tags = tags
    }
}

/// AI Elements' todo panel — a plan-derived checklist whose rows cycle
/// pending / in-progress / completed on tap, with a "N/M done" tally.
public struct AITodoList: View {
    private let items: [AITodoItem]
    private let onCycle: (AITodoItem.ID) -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ items: [AITodoItem], onCycle: @escaping (AITodoItem.ID) -> Void = { _ in }) {
        self.items = items
        self.onCycle = onCycle
    }

    /// Rows whose status is ``AITodoStatus/completed``.
    public static func doneCount(_ items: [AITodoItem]) -> Int {
        items.filter { $0.status == .completed }.count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            Text("\(Self.doneCount(items))/\(items.count) done")
                .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                .foregroundStyle(palette.mutedForeground)

            VStack(alignment: .leading, spacing: Space.x1) {
                ForEach(items) { item in
                    AITodoRow(item: item) { onCycle(item.id) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One tappable todo row.
struct AITodoRow: View {
    let item: AITodoItem
    let onTap: () -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Space.x2) {
                ShadcnIconView(item.status.systemImage, size: 14)
                    .foregroundStyle(item.status.iconTint ?? palette.mutedForeground)

                Text(item.title)
                    .font(theme.typography.sans(theme.typography.sm))
                    .foregroundStyle(
                        item.status == .completed ? palette.mutedForeground : palette.foreground
                    )
                    .strikethrough(item.status == .completed)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if let actor = item.actor {
                    AITaskItemFile(actor)
                }

                ForEach(item.tags, id: \.self) { tag in
                    AITaskItemFile(tag)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.shadcnBare)
    }
}

/// `TaskItem` — `text-muted-foreground text-sm` line.
public struct AITaskItem<Content: View>: View {
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Space.x1_5) {
            content
        }
        .font(theme.typography.sans(theme.typography.sm))
        .foregroundStyle(palette.mutedForeground)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension AITaskItem where Content == Text {
    public init(_ text: String) {
        self.init { Text(text) }
    }
}

/// `TaskItemFile` — the `rounded-md border bg-secondary px-1.5 py-0.5` chip
/// used to name a file inside a task line.
public struct AITaskItemFile: View {
    private let name: String
    private let systemImage: String?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ name: String, systemImage: String? = nil) {
        self.name = name
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: Space.x1) {
            if let systemImage {
                ShadcnIconView(systemImage, size: 12)
            }
            Text(name)
        }
        .font(theme.typography.sans(theme.typography.xs))
        .foregroundStyle(palette.foreground)
        .padding(.horizontal, Space.x1_5)
        .padding(.vertical, Space.x0_5)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.secondary)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
        .fixedSize()
    }
}

/// AI Elements' `Sources` — "Used N sources", expanding to the list.
public struct AISources: View {
    private let sources: [AISource]
    private let defaultOpen: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ sources: [AISource], defaultOpen: Bool = false) {
        self.sources = sources
        self.defaultOpen = defaultOpen
    }

    public var body: some View {
        ShadcnDisclosure(defaultOpen: defaultOpen, spacing: Space.x3) { isOpen in
            HStack(spacing: Space.x2) {
                Text("Used \(sources.count) sources")
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                ShadcnDisclosureChevron(isOpen: isOpen)
                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.primary)
            .contentShape(Rectangle())
        } content: {
            VStack(alignment: .leading, spacing: Space.x2) {
                ForEach(sources) { source in
                    AISourceRow(source: source)
                }
            }
        }
    }
}

/// One cited source.
public struct AISource: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let url: URL?

    public init(id: String = UUID().uuidString, title: String, url: URL? = nil) {
        self.id = id
        self.title = title
        self.url = url
    }
}

/// `Source` — `flex items-center gap-2` link with a book glyph.
public struct AISourceRow: View {
    private let source: AISource

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.openURL) private var openURL

    public init(source: AISource) {
        self.source = source
    }

    public var body: some View {
        Button {
            if let url = source.url { openURL(url) }
        } label: {
            HStack(spacing: Space.x2) {
                ShadcnIconView(ShadcnIcon.book, size: 16)
                Text(source.title)
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(palette.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.shadcnBare)
        .disabled(source.url == nil)
    }
}

/// AI Elements' `Suggestions` — a horizontally scrolling row of pill buttons.
public struct AISuggestions: View {
    private let suggestions: [String]
    private let onSelect: (String) -> Void

    public init(_ suggestions: [String], onSelect: @escaping (String) -> Void) {
        self.suggestions = suggestions
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.x2) {
                ForEach(suggestions, id: \.self) { suggestion in
                    AISuggestion(suggestion, onSelect: onSelect)
                }
            }
        }
    }
}

/// `Suggestion` — `outline` + `sm` + `rounded-full px-4`.
public struct AISuggestion: View {
    private let suggestion: String
    private let onSelect: (String) -> Void

    @Environment(\.shadcnTheme) private var theme

    public init(_ suggestion: String, onSelect: @escaping (String) -> Void) {
        self.suggestion = suggestion
        self.onSelect = onSelect
    }

    public var body: some View {
        Button { onSelect(suggestion) } label: {
            Text(suggestion)
                .padding(.horizontal, Space.x1)
        }
        .buttonStyle(
            ShadcnButtonStyle(
                variant: .outline,
                size: .small,
                cornerRadius: theme.radius.full
            )
        )
        .fixedSize()
    }
}
