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
