import ShadcnUI
import SwiftUI

/// Lifecycle of a tool call. Mirrors `ToolUIPart["state"]` across AI SDK v5
/// and v6.
public enum AIToolState: String, Sendable, CaseIterable {
    case inputStreaming = "input-streaming"
    case inputAvailable = "input-available"
    case approvalRequested = "approval-requested"
    case approvalResponded = "approval-responded"
    case outputAvailable = "output-available"
    case outputError = "output-error"
    case outputDenied = "output-denied"

    /// Badge copy, verbatim from the source.
    public var label: String {
        switch self {
        case .inputStreaming: "Pending"
        case .inputAvailable: "Running"
        case .approvalRequested: "Awaiting Approval"
        case .approvalResponded: "Responded"
        case .outputAvailable: "Completed"
        case .outputError: "Error"
        case .outputDenied: "Denied"
        }
    }

    public var systemImage: String {
        switch self {
        case .inputStreaming: ShadcnIcon.circle
        case .inputAvailable, .approvalRequested: ShadcnIcon.clock
        case .approvalResponded, .outputAvailable: ShadcnIcon.checkCircle
        case .outputError, .outputDenied: ShadcnIcon.xCircle
        }
    }

    /// The Tailwind palette colour the original hardcodes on each status icon.
    public var iconTint: Color? {
        switch self {
        case .inputStreaming, .inputAvailable: nil
        case .approvalRequested: AITailwindColor.yellow600
        case .approvalResponded: AITailwindColor.blue600
        case .outputAvailable: AITailwindColor.green600
        case .outputError: AITailwindColor.red600
        case .outputDenied: AITailwindColor.orange600
        }
    }
}

/// The handful of fixed Tailwind swatches AI Elements uses outside the token
/// system, for status that must read the same in either appearance.
public enum AITailwindColor {
    public static let yellow600 = Color(red: 0xCA / 255, green: 0x8A / 255, blue: 0x04 / 255)
    public static let blue600 = Color(red: 0x25 / 255, green: 0x63 / 255, blue: 0xEB / 255)
    public static let green600 = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
    public static let red600 = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    public static let orange600 = Color(red: 0xEA / 255, green: 0x58 / 255, blue: 0x0C / 255)
}

// MARK: - Activity panel

/// One completed tool call, as tracked by an ``AIActivityPanel``.
public struct AIActivityEvent: Identifiable, Sendable {
    public let id: String
    public let toolName: String
    public let duration: TimeInterval
    public let subagent: String?

    public init(
        id: String = UUID().uuidString,
        toolName: String,
        duration: TimeInterval,
        subagent: String? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.duration = duration
        self.subagent = subagent
    }
}

/// One file touched during the run, as tracked by an ``AIActivityPanel``.
public struct AIActivityFileChange: Identifiable, Sendable {
    public let id: String
    public let path: String
    public let additions: Int
    public let deletions: Int

    public init(
        id: String = UUID().uuidString,
        path: String,
        additions: Int = 0,
        deletions: Int = 0
    ) {
        self.id = id
        self.path = path
        self.additions = additions
        self.deletions = deletions
    }
}

/// The pure roll-up behind ``AIActivityPanel``'s summary line — unit-testable
/// without building a view.
public enum AIActivitySummary {
    /// One clause per non-empty category: `"N tool calls"`, `"N subagents"`,
    /// `"N changes"`, each pluralized on its own count.
    public static func summarize(
        events: [AIActivityEvent],
        changes: [AIActivityFileChange]
    ) -> [String] {
        var lines: [String] = []

        if !events.isEmpty {
            lines.append("\(events.count) tool \(events.count == 1 ? "call" : "calls")")
        }

        let subagents = Set(events.compactMap(\.subagent))
        if !subagents.isEmpty {
            lines.append("\(subagents.count) \(subagents.count == 1 ? "subagent" : "subagents")")
        }

        if !changes.isEmpty {
            lines.append("\(changes.count) \(changes.count == 1 ? "change" : "changes")")
        }

        return lines
    }
}

/// AI Elements' `ActivityPanel` — a run's tool-call durations, subagent
/// fan-out, and file changes, rolled up under one summary line.
public struct AIActivityPanel: View {
    private let events: [AIActivityEvent]
    private let changes: [AIActivityFileChange]

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(events: [AIActivityEvent], changes: [AIActivityFileChange] = []) {
        self.events = events
        self.changes = changes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            HStack(spacing: Space.x3) {
                ForEach(
                    Array(AIActivitySummary.summarize(events: events, changes: changes).enumerated()),
                    id: \.offset
                ) { _, line in
                    Text(line)
                        .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                        .foregroundStyle(palette.mutedForeground)
                }
                Spacer(minLength: 0)
            }

            if !events.isEmpty {
                VStack(alignment: .leading, spacing: Space.x1) {
                    AIToolSectionCaption("Tool calls")
                    ForEach(events) { event in
                        HStack(spacing: Space.x2) {
                            ShadcnIconView(ShadcnIcon.wrench, size: 12)
                                .foregroundStyle(palette.mutedForeground)
                            Text(event.toolName).lineLimit(1)
                            if let subagent = event.subagent {
                                AITaskItemFile(subagent)
                            }
                            Spacer(minLength: 0)
                            Text(Self.formattedDuration(event.duration))
                                .font(theme.typography.mono(theme.typography.xs))
                                .foregroundStyle(palette.mutedForeground)
                        }
                        .font(theme.typography.sans(theme.typography.xs))
                        .foregroundStyle(palette.foreground)
                    }
                }
            }

            if !changes.isEmpty {
                VStack(alignment: .leading, spacing: Space.x1) {
                    AIToolSectionCaption("File changes")
                    ForEach(changes) { change in
                        HStack(spacing: Space.x2) {
                            ShadcnIconView(ShadcnIcon.file, size: 12)
                                .foregroundStyle(palette.mutedForeground)
                            Text(change.path).lineLimit(1)
                            Spacer(minLength: 0)
                            Text("+\(change.additions)")
                                .foregroundStyle(AITailwindColor.green600)
                            Text("-\(change.deletions)")
                                .foregroundStyle(AITailwindColor.red600)
                        }
                        .font(theme.typography.mono(theme.typography.xs))
                    }
                }
            }
        }
        .padding(Space.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.muted.opacity(0.3))
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
    }

    private static func formattedDuration(_ interval: TimeInterval) -> String {
        interval < 1
            ? String(format: "%.0fms", interval * 1000)
            : String(format: "%.1fs", interval)
    }
}

/// AI Elements' `Tool` — a bordered, collapsible record of one tool call.
public struct AITool<Content: View>: View {
    private let name: String
    private let state: AIToolState
    private let defaultOpen: Bool
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        name: String,
        state: AIToolState,
        defaultOpen: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.name = name
        self.state = state
        self.defaultOpen = defaultOpen
        self.content = content()
    }

    public var body: some View {
        ShadcnDisclosure(defaultOpen: defaultOpen) { isOpen in
            AIToolHeader(name: name, state: state, isOpen: isOpen)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(Color.clear)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
    }

}

/// `ToolMarker` — a single-line, non-disclosing tool row for dense
/// transcripts where the full ``AITool`` card reads as too heavy.
public struct AIToolMarker: View {
    private let name: String
    private let state: AIToolState

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(name: String, state: AIToolState) {
        self.name = name
        self.state = state
    }

    public var body: some View {
        HStack(spacing: Space.x1_5) {
            ShadcnIconView(state.systemImage, size: 12)
                .foregroundStyle(state.iconTint ?? palette.mutedForeground)
            Text(name)
                .font(theme.typography.mono(theme.typography.xs))
                .foregroundStyle(palette.mutedForeground)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(state.label)
                .font(theme.typography.sans(theme.typography.xs))
                .foregroundStyle(palette.mutedForeground.opacity(0.7))
        }
        .padding(.horizontal, Space.x2)
        .padding(.vertical, Space.x1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The tool's title bar.
struct AIToolHeader: View {
    let name: String
    let state: AIToolState
    let isOpen: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    var body: some View {
        HStack(spacing: Space.x4) {
            HStack(spacing: Space.x2) {
                ShadcnIconView(ShadcnIcon.wrench, size: 16)
                    .foregroundStyle(palette.mutedForeground)
                Text(name)
                    .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                    .foregroundStyle(palette.foreground)
                statusBadge
            }
            Spacer(minLength: 0)
            ShadcnDisclosureChevron(isOpen: isOpen)
                .foregroundStyle(palette.mutedForeground)
        }
        // Tighter than the web's `p-3`: these stack in a narrow sidebar, where
        // the original padding reads as a lot of dead space per card.
        .padding(.horizontal, Space.x2_5)
        .padding(.vertical, Space.x2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let tint = state.iconTint {
            ShadcnBadge(
                state.label,
                systemImage: state.systemImage,
                iconTint: tint,
                variant: .secondary
            )
        } else {
            ShadcnBadge(state.label, systemImage: state.systemImage, variant: .secondary)
        }
    }
}

/// `ToolInput` — an uppercase "Parameters" caption over a `bg-muted/50` JSON
/// block.
public struct AIToolInput: View {
    private let json: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(json: String) {
        self.json = json
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            AIToolSectionCaption("Parameters")
            AICodeBlock(code: json, language: "json")
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                        .fill(palette.muted.opacity(0.5))
                )
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x2_5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `ToolOutput` — "Result", or "Error" on a `bg-destructive/10` surface.
public struct AIToolOutput: View {
    private let output: String?
    private let errorText: String?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(output: String? = nil, errorText: String? = nil) {
        self.output = output
        self.errorText = errorText
    }

    public var body: some View {
        // The original renders nothing at all when both are absent.
        if output != nil || errorText != nil {
            VStack(alignment: .leading, spacing: Space.x2) {
                AIToolSectionCaption(errorText != nil ? "Error" : "Result")

                if let errorText {
                    Text(errorText)
                        .font(theme.typography.mono(theme.typography.xs))
                        .foregroundStyle(palette.destructive)
                        .padding(Space.x3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                                .fill(palette.destructive.opacity(0.1))
                        )
                } else if let output {
                    AICodeBlock(code: output, language: "json")
                }
            }
            .padding(.horizontal, Space.x3)
            .padding(.vertical, Space.x2_5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The `font-medium text-muted-foreground text-xs uppercase tracking-wide`
/// caption shared by tool sections.
struct AIToolSectionCaption: View {
    private let text: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(theme.typography.sans(theme.typography.xs, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(palette.mutedForeground)
    }
}
