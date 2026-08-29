import ShadcnUI
import SwiftUI

/// Layout and pinning metrics for ``AIConversation``.
///
/// The standard preset preserves AI Elements' existing transcript geometry.
/// Use ``compact`` for denser sidebars without changing every message view.
public struct AIConversationStyle: Equatable, Sendable {
    public var itemSpacing: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var bottomTolerance: CGFloat

    public init(
        itemSpacing: CGFloat = 32,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 16,
        bottomTolerance: CGFloat = 8
    ) {
        self.itemSpacing = itemSpacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.bottomTolerance = bottomTolerance
    }

    public static let standard = AIConversationStyle()

    public static let compact = AIConversationStyle(itemSpacing: 16)
}

enum AIConversationPinningAction: Equatable, Sendable {
    case none
    case scrollToBottom
}

struct AIConversationGeometry: Equatable, Sendable {
    var contentMinY: CGFloat
    var contentHeight: CGFloat
    var viewportHeight: CGFloat

    var distanceFromBottom: CGFloat {
        max(0, contentMinY + contentHeight - viewportHeight)
    }

    func isAtBottom(tolerance: CGFloat) -> Bool {
        distanceFromBottom <= max(0, tolerance)
    }
}

/// Reduces layout observations into explicit pinning decisions.
///
/// An offset-only change is a scroll gesture. Content-height and viewport-height
/// changes are layout events, so they keep following enabled and request the new
/// bottom instead of masquerading as manual history scrolling.
struct AIConversationPinningState: Equatable, Sendable {
    private(set) var isFollowing = true
    private(set) var isScrollPending = false
    private var geometry: AIConversationGeometry?

    mutating func geometryDidChange(
        _ next: AIConversationGeometry,
        bottomTolerance: CGFloat
    ) -> AIConversationPinningAction {
        let previous = geometry
        geometry = next

        if next.isAtBottom(tolerance: bottomTolerance) {
            isFollowing = true
            isScrollPending = false
            return .none
        }

        guard isFollowing else { return .none }

        guard let previous else {
            isScrollPending = true
            return .scrollToBottom
        }

        let contentChanged = differs(next.contentHeight, from: previous.contentHeight)
        let viewportChanged = differs(next.viewportHeight, from: previous.viewportHeight)
        let movedAwayFromBottom = next.contentMinY > previous.contentMinY + 0.5

        if movedAwayFromBottom && !viewportChanged {
            // Streaming can grow content in the same layout pass that the user
            // scrolls toward history. The origin delta is the gesture signal;
            // do not let the simultaneous height delta yank them back down.
            isFollowing = false
            isScrollPending = false
            return .none
        }

        if contentChanged || viewportChanged {
            isScrollPending = true
            return .scrollToBottom
        }

        if isScrollPending {
            if next.distanceFromBottom > previous.distanceFromBottom + 0.5 {
                // A gesture moving away from the bottom supersedes an in-flight
                // programmatic scroll.
                isFollowing = false
                isScrollPending = false
            }
            return .none
        }

        isFollowing = false
        return .none
    }

    mutating func contentDidChange() -> AIConversationPinningAction {
        isFollowing ? .scrollToBottom : .none
    }

    mutating func scrollToLatest() -> AIConversationPinningAction {
        isFollowing = true
        isScrollPending = true
        return .scrollToBottom
    }

    private func differs(_ lhs: CGFloat, from rhs: CGFloat) -> Bool {
        abs(lhs - rhs) > 0.5
    }
}

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
    private let style: AIConversationStyle

    @State private var pinning = AIConversationPinningState()

    private static var bottomAnchorID: String { "ai-conversation-bottom" }

    public init(
        streamToken: AnyHashable = 0,
        style: AIConversationStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.streamToken = streamToken
        self.style = style
        self.content = content()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: style.itemSpacing) {
                            content
                        }
                        .padding(.horizontal, style.horizontalPadding)
                        .padding(.vertical, style.verticalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorID)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(contentGeometryDetector)
                }
                .coordinateSpace(name: "ai-conversation")
                .background(viewportGeometryDetector)
                .onPreferenceChange(AIConversationGeometryKey.self) { value in
                    guard let geometry = value.geometry else { return }
                    let action = pinning.geometryDidChange(
                        geometry,
                        bottomTolerance: style.bottomTolerance
                    )
                    perform(action, with: proxy, animated: false)
                }

                if !pinning.isFollowing {
                    scrollButton(proxy: proxy)
                        .padding(.bottom, style.verticalPadding)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onChange(of: streamToken) { _, _ in
                let action = pinning.contentDidChange()
                perform(action, with: proxy, animated: true)
            }
            .animation(.easeOut(duration: 0.15), value: pinning.isFollowing)
        }
        .accessibilityLabel("Conversation")
    }

    private var contentGeometryDetector: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named("ai-conversation"))
            Color.clear.preference(
                key: AIConversationGeometryKey.self,
                value: AIConversationGeometryPreference(
                    contentMinY: frame.minY,
                    contentHeight: frame.height
                )
            )
        }
    }

    private var viewportGeometryDetector: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: AIConversationGeometryKey.self,
                value: AIConversationGeometryPreference(viewportHeight: geometry.size.height)
            )
        }
    }

    private func scrollButton(proxy: ScrollViewProxy) -> some View {
        ShadcnButton(icon: ShadcnIcon.arrowDown, variant: .outline, size: .icon) {
            let action = pinning.scrollToLatest()
            perform(action, with: proxy, animated: true)
        }
        .clipShape(Circle())
        .accessibilityLabel("Scroll to latest")
    }

    private func perform(
        _ action: AIConversationPinningAction,
        with proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard action == .scrollToBottom else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct AIConversationGeometryPreference: Equatable {
    var contentMinY: CGFloat?
    var contentHeight: CGFloat?
    var viewportHeight: CGFloat?

    init(
        contentMinY: CGFloat? = nil,
        contentHeight: CGFloat? = nil,
        viewportHeight: CGFloat? = nil
    ) {
        self.contentMinY = contentMinY
        self.contentHeight = contentHeight
        self.viewportHeight = viewportHeight
    }

    var geometry: AIConversationGeometry? {
        guard
            let contentMinY,
            let contentHeight,
            let viewportHeight,
            contentMinY.isFinite,
            contentHeight.isFinite,
            viewportHeight.isFinite,
            contentHeight >= 0,
            viewportHeight > 0
        else { return nil }

        return AIConversationGeometry(
            contentMinY: contentMinY,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        )
    }
}

private struct AIConversationGeometryKey: PreferenceKey {
    static let defaultValue = AIConversationGeometryPreference()

    static func reduce(
        value: inout AIConversationGeometryPreference,
        nextValue: () -> AIConversationGeometryPreference
    ) {
        let next = nextValue()
        if let contentMinY = next.contentMinY {
            value.contentMinY = contentMinY
        }
        if let contentHeight = next.contentHeight {
            value.contentHeight = contentHeight
        }
        if let viewportHeight = next.viewportHeight {
            value.viewportHeight = viewportHeight
        }
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
