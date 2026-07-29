import ShadcnUI
import SwiftUI

/// AI Elements' `Reasoning` — a collapsible "Thinking…" panel that times itself
/// while streaming and folds away a second after it finishes.
public struct AIReasoning: View {
    private let content: String
    private let isStreaming: Bool
    /// Seconds spent thinking. Supply it to skip the internal timing.
    private let duration: Int?
    private let autoClose: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    @State private var isOpen: Bool
    @State private var startedAt: Date?
    @State private var measuredDuration: Int?
    @State private var hasAutoClosed = false

    private static let autoCloseDelay: Double = 1

    public init(
        content: String,
        isStreaming: Bool = false,
        duration: Int? = nil,
        defaultOpen: Bool = true,
        autoClose: Bool = true
    ) {
        self.content = content
        self.isStreaming = isStreaming
        self.duration = duration
        self.autoClose = autoClose
        self._isOpen = State(initialValue: defaultOpen)
    }

    private var effectiveDuration: Int? { duration ?? measuredDuration }

    public var body: some View {
        ShadcnCollapsible(isOpen: $isOpen, spacing: Space.x4) { isOpen in
            trigger(isOpen: isOpen)
        } content: {
            AIResponse(content)
                .foregroundStyle(palette.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: isStreaming) { _, streaming in
            if streaming {
                if startedAt == nil { startedAt = Date() }
            } else if let startedAt {
                measuredDuration = Int(ceil(Date().timeIntervalSince(startedAt)))
                self.startedAt = nil
                scheduleAutoClose()
            }
        }
        .onAppear {
            if isStreaming, startedAt == nil { startedAt = Date() }
        }
    }

    /// Mirrors the original: close once, a beat after streaming stops, and only
    /// if the panel opened itself.
    private func scheduleAutoClose() {
        guard autoClose, !hasAutoClosed, isOpen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoCloseDelay) {
            guard !isStreaming else { return }
            withAnimation(.easeOut(duration: 0.2)) { isOpen = false }
            hasAutoClosed = true
        }
    }

    private func trigger(isOpen: Bool) -> some View {
        HStack(spacing: Space.x2) {
            ShadcnIconView(ShadcnIcon.brain, size: 16)
            thinkingMessage
            ShadcnDisclosureChevron(isOpen: isOpen)
            Spacer(minLength: 0)
        }
        .foregroundStyle(palette.mutedForeground)
        .font(theme.typography.sans(theme.typography.sm))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thinkingMessage: some View {
        if isStreaming || effectiveDuration == 0 {
            AIShimmer("Thinking...", duration: 1)
        } else if let seconds = effectiveDuration {
            Text("Thought for \(seconds) seconds")
        } else {
            Text("Thought for a few seconds")
        }
    }
}

/// AI Elements' `ChainOfThought` — a brain-headed collapsible holding a
/// vertical run of steps.
public struct AIChainOfThought<Content: View>: View {
    private let title: String
    private let defaultOpen: Bool
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        title: String = "Chain of Thought",
        defaultOpen: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.defaultOpen = defaultOpen
        self.content = content()
    }

    public var body: some View {
        ShadcnDisclosure(defaultOpen: defaultOpen, spacing: Space.x2) { isOpen in
            HStack(spacing: Space.x2) {
                ShadcnIconView(ShadcnIcon.brain, size: 16)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ShadcnDisclosureChevron(isOpen: isOpen)
            }
            .font(theme.typography.sans(theme.typography.sm))
            .foregroundStyle(palette.mutedForeground)
            .contentShape(Rectangle())
        } content: {
            VStack(alignment: .leading, spacing: Space.x3) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// How far along a `AIChainOfThoughtStep` is.
public enum AIChainOfThoughtStatus: Sendable {
    case complete
    case active
    case pending
}

/// `ChainOfThoughtStep` — icon and connector rail on the left, label and
/// description on the right.
public struct AIChainOfThoughtStep<Content: View>: View {
    private let label: String
    private let description: String?
    private let status: AIChainOfThoughtStatus
    private let systemImage: String
    private let isLast: Bool
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        label: String,
        description: String? = nil,
        status: AIChainOfThoughtStatus = .complete,
        systemImage: String = ShadcnIcon.circleFilled,
        isLast: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.description = description
        self.status = status
        self.systemImage = systemImage
        self.isLast = isLast
        self.content = content()
    }

    private var foreground: Color {
        switch status {
        case .complete: palette.mutedForeground
        case .active: palette.foreground
        case .pending: palette.mutedForeground.opacity(0.5)
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Space.x2) {
            // Icon plus the hairline rail that joins this step to the next.
            VStack(spacing: 0) {
                ShadcnIconView(systemImage, size: 16)
                    .font(.system(size: 6))
                if !isLast {
                    Rectangle()
                        .fill(palette.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, Space.x1_5)
                }
            }
            .padding(.top, 2)
            .frame(width: 16)

            VStack(alignment: .leading, spacing: Space.x2) {
                Text(label)
                    .font(theme.typography.sans(theme.typography.sm))
                if let description {
                    Text(description)
                        .font(theme.typography.sans(theme.typography.xs))
                        .foregroundStyle(palette.mutedForeground)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(foreground)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension AIChainOfThoughtStep where Content == EmptyView {
    public init(
        label: String,
        description: String? = nil,
        status: AIChainOfThoughtStatus = .complete,
        systemImage: String = ShadcnIcon.circleFilled,
        isLast: Bool = false
    ) {
        self.init(
            label: label,
            description: description,
            status: status,
            systemImage: systemImage,
            isLast: isLast
        ) {
            EmptyView()
        }
    }
}

/// `ChainOfThoughtSearchResults` — a wrapping row of secondary pills.
public struct AIChainOfThoughtSearchResults: View {
    private let results: [String]

    public init(_ results: [String]) {
        self.results = results
    }

    public var body: some View {
        ShadcnWrapLayout(spacing: Space.x2, lineSpacing: Space.x2) {
            ForEach(results, id: \.self) { result in
                ShadcnBadge(result, variant: .secondary)
            }
        }
    }
}
