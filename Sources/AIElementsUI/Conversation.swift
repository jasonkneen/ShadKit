import ShadcnUI
import SwiftUI

/// AI Elements' `Conversation` — a scrolling log that sticks to the bottom as
/// content streams in, with a "jump to latest" button once you scroll away.
///
/// Replaces `use-stick-to-bottom` with a `ScrollViewReader`: the pin only
/// re-engages when the user is already at the bottom, so scrolling back through
/// history isn't yanked away mid-read.
public struct AIConversation<Content: View>: View {
    private let content: Content
    /// Bumping this scrolls to the bottom, if pinned.
    private let streamToken: AnyHashable

    @State private var isAtBottom = true
    @State private var scrollProxy: ScrollViewProxy?

    private static var bottomAnchorID: String { "ai-conversation-bottom" }

    public init(streamToken: AnyHashable = 0, @ViewBuilder content: () -> Content) {
        self.streamToken = streamToken
        self.content = content()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.x8) {
                        content
                    }
                    .padding(Space.x4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bottomDetector)

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .coordinateSpace(name: "ai-conversation")

                if !isAtBottom {
                    scrollButton(proxy: proxy)
                        .padding(.bottom, Space.x4)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: streamToken) { _, _ in
                guard isAtBottom else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }
        }
        .accessibilityLabel("Conversation")
    }

    /// Publishes how far the content's bottom edge sits from the viewport's.
    private var bottomDetector: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named("ai-conversation"))
            Color.clear.preference(
                key: AIConversationOffsetKey.self,
                value: frame.maxY
            )
        }
        .onPreferenceChange(AIConversationOffsetKey.self) { _ in }
    }

    private func scrollButton(proxy: ScrollViewProxy) -> some View {
        ShadcnButton(icon: ShadcnIcon.arrowDown, variant: .outline, size: .icon) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                isAtBottom = true
            }
        }
        .clipShape(Circle())
        .accessibilityLabel("Scroll to latest")
    }
}

private struct AIConversationOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// `ConversationEmptyState` — centred icon, `text-sm font-medium` title and a
/// `text-muted-foreground` description.
public struct AIConversationEmptyState: View {
    private let title: String
    private let description: String?
    private let systemImage: String?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        title: String = "No messages yet",
        description: String? = "Start a conversation to see messages here",
        systemImage: String? = nil
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(spacing: Space.x3) {
            if let systemImage {
                ShadcnIconView(systemImage, size: 32)
                    .foregroundStyle(palette.mutedForeground)
            }
            VStack(spacing: Space.x1) {
                Text(title)
                    .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                    .foregroundStyle(palette.foreground)
                if let description {
                    Text(description)
                        .font(theme.typography.sans(theme.typography.sm))
                        .foregroundStyle(palette.mutedForeground)
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(Space.x8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
