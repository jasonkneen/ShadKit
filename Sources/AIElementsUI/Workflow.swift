import ShadcnUI
import SwiftUI

// MARK: - Plan

/// AI Elements' `Plan` — a shadow-less card whose body collapses behind a
/// chevron, with the title shimmering while the plan streams in.
public struct AIPlan<Content: View, Footer: View>: View {
    private let title: String
    private let description: String?
    private let isStreaming: Bool
    private let defaultOpen: Bool
    private let content: Content
    private let footer: Footer

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isOpen: Bool

    public init(
        title: String,
        description: String? = nil,
        isStreaming: Bool = false,
        defaultOpen: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.description = description
        self.isStreaming = isStreaming
        self.defaultOpen = defaultOpen
        self.content = content()
        self.footer = footer()
        self._isOpen = State(initialValue: defaultOpen)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x6) {
            header
            if isOpen {
                VStack(alignment: .leading, spacing: Space.x3) {
                    content
                }
                .padding(.horizontal, Space.x6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .offset(y: -8)))

                footer
                    .padding(.horizontal, Space.x6)
            }
        }
        .padding(.vertical, Space.x6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(palette.card)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.xl)
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Space.x4) {
            VStack(alignment: .leading, spacing: Space.x1_5) {
                if isStreaming {
                    AIShimmer(
                        title,
                        font: theme.typography.sans(theme.typography.base, weight: .semibold)
                    )
                } else {
                    ShadcnCardTitle(title)
                }
                if let description {
                    if isStreaming {
                        AIShimmer(description)
                    } else {
                        ShadcnCardDescription(description)
                    }
                }
            }
            Spacer(minLength: 0)
            ShadcnButton(
                icon: ShadcnIcon.chevronsUpDown,
                variant: .ghost,
                size: .iconSM
            ) {
                withAnimation(.easeOut(duration: 0.2)) { isOpen.toggle() }
            }
            .accessibilityLabel("Toggle plan")
        }
        .padding(.horizontal, Space.x6)
    }
}

extension AIPlan where Footer == EmptyView {
    public init(
        title: String,
        description: String? = nil,
        isStreaming: Bool = false,
        defaultOpen: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            description: description,
            isStreaming: isStreaming,
            defaultOpen: defaultOpen,
            content: content,
            footer: { EmptyView() }
        )
    }
}

// MARK: - Confirmation

/// AI Elements' `Confirmation` — the approve/deny prompt shown when a tool call
/// needs a human decision.
///
/// Renders nothing until the tool has actually asked, matching the original's
/// early return on the streaming states.
public struct AIConfirmation: View {
    private let message: String
    private let state: AIToolState
    private let isApproved: Bool?
    private let onApprove: () -> Void
    private let onDeny: () -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        message: String,
        state: AIToolState,
        isApproved: Bool? = nil,
        onApprove: @escaping () -> Void = {},
        onDeny: @escaping () -> Void = {}
    ) {
        self.message = message
        self.state = state
        self.isApproved = isApproved
        self.onApprove = onApprove
        self.onDeny = onDeny
    }

    private var isPending: Bool { state == .approvalRequested }

    private var isResolved: Bool {
        state == .approvalResponded || state == .outputDenied || state == .outputAvailable
    }

    public var body: some View {
        if state != .inputStreaming && state != .inputAvailable {
            ShadcnAlert {
                ShadcnAlertDescription(message)

                if isPending {
                    HStack(spacing: Space.x2) {
                        Spacer(minLength: 0)
                        ShadcnButton("Deny", variant: .outline, size: .small, action: onDeny)
                        ShadcnButton("Approve", variant: .primary, size: .small, action: onApprove)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else if isResolved, let isApproved {
                    HStack(spacing: Space.x1_5) {
                        ShadcnIconView(
                            isApproved ? ShadcnIcon.checkCircle : ShadcnIcon.xCircle,
                            size: 14
                        )
                        .foregroundStyle(
                            isApproved ? AITailwindColor.green600 : AITailwindColor.orange600
                        )
                        Text(isApproved ? "Approved" : "Denied")
                            .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                            .foregroundStyle(palette.mutedForeground)
                    }
                }
            }
        }
    }
}

// MARK: - Checkpoint

/// AI Elements' `Checkpoint` — a bookmark, a label, and a rule filling the rest
/// of the row.
public struct AICheckpoint: View {
    private let label: String
    private let tooltip: String?
    private let action: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(label: String, tooltip: String? = nil, action: (() -> Void)? = nil) {
        self.label = label
        self.tooltip = tooltip
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 2) {
            ShadcnIconView("bookmark", size: 16)

            Group {
                if let action {
                    ShadcnButton(label, variant: .ghost, size: .small, action: action)
                } else {
                    Text(label)
                        .font(theme.typography.sans(theme.typography.sm))
                        .padding(.horizontal, Space.x3)
                }
            }
            .applyIf(tooltip != nil) { $0.shadcnTooltip(tooltip ?? "") }

            ShadcnSeparator()
        }
        .foregroundStyle(palette.mutedForeground)
    }
}

// MARK: - Queue

/// One queued item.
public struct AIQueueItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String?
    public let isCompleted: Bool
    public let attachments: [String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        isCompleted: Bool = false,
        attachments: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.attachments = attachments
    }
}

/// AI Elements' `Queue` — collapsible sections of pending and completed work.
public struct AIQueue: View {
    private let sections: [(label: String, systemImage: String, items: [AIQueueItem])]

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(sections: [(label: String, systemImage: String, items: [AIQueueItem])]) {
        self.sections = sections
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                AIQueueSection(
                    label: section.label,
                    systemImage: section.systemImage,
                    items: section.items
                )
            }
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x2)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(palette.background)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.xl)
        .shadcnShadow(.xs)
    }
}

/// `QueueSection` — a `bg-muted/40` header over the section's rows.
public struct AIQueueSection: View {
    private let label: String
    private let systemImage: String
    private let items: [AIQueueItem]

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(label: String, systemImage: String, items: [AIQueueItem]) {
        self.label = label
        self.systemImage = systemImage
        self.items = items
    }

    public var body: some View {
        ShadcnDisclosure(defaultOpen: true, spacing: Space.x2) { isOpen in
            HStack(spacing: Space.x2) {
                // Closed rotates to -90°, not 180°, in this component.
                ShadcnIconView(ShadcnIcon.chevronDown, size: 16)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
                    .animation(.easeOut(duration: 0.2), value: isOpen)
                ShadcnIconView(systemImage, size: 16)
                Text("\(items.count) \(label)")
                Spacer(minLength: 0)
            }
            .font(theme.typography.sans(theme.typography.sm, weight: .medium))
            .foregroundStyle(palette.mutedForeground)
            .padding(.horizontal, Space.x3)
            .padding(.vertical, Space.x2)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                    .fill(palette.muted.opacity(0.4))
            )
            .contentShape(Rectangle())
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    AIQueueRow(item: item)
                }
            }
        }
    }
}

/// One `QueueItem` row.
struct AIQueueRow: View {
    let item: AIQueueItem

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(alignment: .top, spacing: Space.x3) {
                // `size-2.5 rounded-full border` status dot.
                Circle()
                    .fill(
                        item.isCompleted
                            ? palette.mutedForeground.opacity(0.1)
                            : Color.clear
                    )
                    .overlay(
                        Circle().strokeBorder(
                            palette.mutedForeground.opacity(item.isCompleted ? 0.2 : 0.5),
                            lineWidth: 1
                        )
                    )
                    .frame(width: 10, height: 10)
                    .padding(.top, 2)

                Text(item.title)
                    .font(theme.typography.sans(theme.typography.sm))
                    .foregroundStyle(
                        palette.mutedForeground.opacity(item.isCompleted ? 0.5 : 1)
                    )
                    .strikethrough(item.isCompleted)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            if let description = item.description {
                Text(description)
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(
                        palette.mutedForeground.opacity(item.isCompleted ? 0.4 : 1)
                    )
                    .strikethrough(item.isCompleted)
                    .padding(.leading, Space.x6)
            }

            if !item.attachments.isEmpty {
                ShadcnWrapLayout(spacing: Space.x2, lineSpacing: Space.x2) {
                    ForEach(item.attachments, id: \.self) { name in
                        HStack(spacing: Space.x1) {
                            ShadcnIconView(ShadcnIcon.paperclip, size: 12)
                            Text(name).lineLimit(1)
                        }
                        .font(theme.typography.sans(theme.typography.xs))
                        .padding(.horizontal, Space.x2)
                        .padding(.vertical, Space.x1)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.muted)
                        )
                        .shadcnBorder(palette.border, cornerRadius: 4)
                    }
                }
                .padding(.leading, Space.x6)
                .padding(.top, Space.x1)
            }
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(isHovering ? palette.muted : .clear)
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - Context

/// Token accounting behind `AIContext`.
public struct AIContextUsage: Sendable {
    public var usedTokens: Int
    public var maxTokens: Int
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var reasoningTokens: Int?
    public var cachedTokens: Int?
    public var totalCost: Double?

    public init(
        usedTokens: Int,
        maxTokens: Int,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        cachedTokens: Int? = nil,
        totalCost: Double? = nil
    ) {
        self.usedTokens = usedTokens
        self.maxTokens = maxTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.cachedTokens = cachedTokens
        self.totalCost = totalCost
    }

    public var usedFraction: Double {
        guard maxTokens > 0 else { return 0 }
        return min(Double(usedTokens) / Double(maxTokens), 1)
    }
}

/// AI Elements' `Context` — a percentage readout that opens into a token and
/// cost breakdown.
public struct AIContext: View {
    private let usage: AIContextUsage

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isOpen = false

    public init(usage: AIContextUsage) {
        self.usage = usage
    }

    public var body: some View {
        ShadcnPopover(isPresented: $isOpen, width: 240) {
            Button {
                withAnimation(.easeOut(duration: 0.12)) { isOpen.toggle() }
            } label: {
                HStack(spacing: Space.x1_5) {
                    AIContextGauge(fraction: usage.usedFraction)
                    Text(usage.usedFraction.formatted(.percent.precision(.fractionLength(0))))
                        .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                        .foregroundStyle(palette.mutedForeground)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.shadcnBare)
        } content: {
            breakdown
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            HStack {
                Text(usage.usedFraction.formatted(.percent.precision(.fractionLength(1))))
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                Spacer()
                Text("\(usage.usedTokens.formatted()) / \(usage.maxTokens.formatted())")
                    .font(theme.typography.mono(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
            }

            ShadcnProgress(value: usage.usedFraction)

            ShadcnSeparator()

            row("Input", usage.inputTokens)
            row("Output", usage.outputTokens)
            row("Reasoning", usage.reasoningTokens)
            row("Cache", usage.cachedTokens)

            if let cost = usage.totalCost {
                ShadcnSeparator()
                HStack {
                    Text("Total cost")
                        .foregroundStyle(palette.mutedForeground)
                    Spacer()
                    Text(cost.formatted(.currency(code: "USD").precision(.fractionLength(4))))
                }
                .font(theme.typography.sans(theme.typography.xs))
            }
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: Int?) -> some View {
        if let value {
            HStack {
                Text(label)
                    .foregroundStyle(palette.mutedForeground)
                Spacer()
                Text(value.formatted())
            }
            .font(theme.typography.sans(theme.typography.xs))
        }
    }
}

/// The little ring that fills as the context window is consumed.
struct AIContextGauge: View {
    let fraction: Double

    @Environment(\.shadcnPalette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.muted, lineWidth: 2)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(palette.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }
}

// MARK: - Model selector

/// A model the user can pick.
public struct AIModelOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let provider: String
    public let systemImage: String?

    public init(id: String, name: String, provider: String, systemImage: String? = nil) {
        self.id = id
        self.name = name
        self.provider = provider
        self.systemImage = systemImage
    }
}

/// AI Elements' `ModelSelector` — a searchable command palette of models,
/// grouped by provider.
public struct AIModelSelector: View {
    private let models: [AIModelOption]
    @Binding private var selection: AIModelOption?
    @Binding private var isPresented: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var query = ""

    public init(
        models: [AIModelOption],
        selection: Binding<AIModelOption?>,
        isPresented: Binding<Bool>
    ) {
        self.models = models
        self._selection = selection
        self._isPresented = isPresented
    }

    private var filtered: [String: [AIModelOption]] {
        let matches = query.isEmpty
            ? models
            : models.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.provider.localizedCaseInsensitiveContains(query)
            }
        return Dictionary(grouping: matches, by: \.provider)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.x2) {
                ShadcnIconView(ShadcnIcon.search, size: 16)
                    .foregroundStyle(palette.mutedForeground)
                ShadcnTextField("Search models...", text: $query)
                    .shadcnBorder(.clear, cornerRadius: 0)
            }
            .padding(.horizontal, Space.x3)

            ShadcnSeparator()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.x1) {
                    if filtered.isEmpty {
                        Text("No models found.")
                            .font(theme.typography.sans(theme.typography.sm))
                            .foregroundStyle(palette.mutedForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.x6)
                    }
                    ForEach(filtered.keys.sorted(), id: \.self) { provider in
                        ShadcnMenuLabel(provider)
                        ForEach(filtered[provider] ?? []) { model in
                            ShadcnMenuItem(
                                model.name,
                                systemImage: model.systemImage,
                                isSelected: model.id == selection?.id
                            ) {
                                selection = model
                                isPresented = false
                            }
                        }
                    }
                }
                .padding(Space.x1)
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 420)
    }
}
