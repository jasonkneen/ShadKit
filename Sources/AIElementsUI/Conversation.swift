import ShadcnUI
import SwiftUI

/// Layout and pinning metrics for ``AIConversation``.
///
/// The standard preset keeps related turns visually connected.
/// Use ``compact`` for denser sidebars without changing every message view.
public struct AIConversationStyle: Equatable, Sendable {
    public var itemSpacing: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var bottomTolerance: CGFloat

    public init(
        itemSpacing: CGFloat = 16,
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

    public static let compact = AIConversationStyle(itemSpacing: 12)
}

/// What ``AIConversation`` watches to decide it should re-pin to the bottom.
///
/// The distinction matters for smoothness. Following the bottom used to start a
/// fresh 0.2s `scrollTo` animation on every streamed token, and each one
/// interrupted the one before it — the transcript stuttered rather than glided.
/// A `counted` token separates "the in-flight answer grew by a token" (pin
/// immediately, no animation) from "a turn landed" (worth animating).
/// Not `Sendable`: the `opaque` case wraps a caller-supplied `AnyHashable`,
/// which isn't. The type is only ever read on the main actor.
public enum AIConversationToken: Hashable {
    /// A caller-supplied value with no structure. Always animates, so existing
    /// call sites keep the behaviour they had.
    case opaque(AnyHashable)
    /// Structured counts the conversation can reason about.
    case counted(itemCount: Int, streamLength: Int, extra: Int)

    public init(itemCount: Int, streamLength: Int = 0, extra: Int = 0) {
        self = .counted(itemCount: itemCount, streamLength: streamLength, extra: extra)
    }

    /// Whether a move from `old` to `new` should glide or snap.
    public static func animatesFollow(from old: Self, to new: Self) -> Bool {
        guard
            case let .counted(oldItems, _, oldExtra) = old,
            case let .counted(newItems, _, newExtra) = new
        else { return true }
        // Only the live tail changed length: pin without animating.
        return oldItems != newItems || oldExtra != newExtra
    }
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

/// One stop on ``AIDial`` — a message, turn, or other addressable point in a
/// transcript. Major ticks draw wider and anchor a preview; minor ticks are
/// the quiet marks between them. `isMajor` means "the human asked this".
// Checked against this toolchain: `AnyHashable` does not conform to
// `Sendable` here (it produces a strict-concurrency warning, not the
// "one-word fix" the outlier looked like), so `AIDialTick` stays
// non-Sendable rather than mis-declare the conformance. Documented as an
// intentional omission — see the package's Sendable review.
public struct AIDialTick: Identifiable {
    public let id: AnyHashable
    public let label: String
    public let isMajor: Bool
    /// Who to credit on the preview card's byline. Defaults to "You" for
    /// major (human) ticks and "Assistant" otherwise.
    public let author: String

    public init(id: AnyHashable, label: String, isMajor: Bool = false, author: String? = nil) {
        self.id = id
        self.label = label
        self.isMajor = isMajor
        self.author = author ?? (isMajor ? "You" : "Assistant")
    }
}

/// Which edge of its container ``AIDial`` pins its rail to.
public enum AIDialSide: Sendable {
    case leading, trailing
}

/// A vertical rail of tick marks pinned to an edge — hover or select one to
/// jump the conversation to that point. Meant to sit as a sibling alongside a
/// scrolling transcript (in a `ZStack`, aligned to `side`), not inline in a
/// column of content. Generic over nothing but the tick's own `AnyHashable`
/// id, so it drives a transcript scrubber (see ``AIDial/ticks(forMessages:)``)
/// or any other sequence of addressable stops.
public struct AIDial: View {
    private let ticks: [AIDialTick]
    private let activeID: AnyHashable?
    private let side: AIDialSide
    private let onSelect: (AnyHashable) -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var hoveredID: AnyHashable?

    private let railHitWidth: CGFloat = Space.step(7)
    private let previewWidth: CGFloat = 288

    public init(
        ticks: [AIDialTick],
        activeID: AnyHashable? = nil,
        side: AIDialSide = .trailing,
        onSelect: @escaping (AnyHashable) -> Void
    ) {
        self.ticks = ticks
        self.activeID = activeID
        self.side = side
        self.onSelect = onSelect
    }

    private var previewIndex: Int? {
        let previewID = hoveredID ?? activeID
        return ticks.firstIndex { $0.id == previewID }
    }

    public var body: some View {
        GeometryReader { geometry in
            let gap = ticks.isEmpty ? geometry.size.height : geometry.size.height / CGFloat(ticks.count)

            ZStack(alignment: side == .leading ? .topLeading : .topTrailing) {
                VStack(spacing: 0) {
                    ForEach(ticks) { tick in
                        tickButton(tick, hitHeight: max(2, gap))
                    }
                }
                .frame(width: railHitWidth)
                // Past ~150 messages in a 300pt rail, `gap` falls under the
                // 2pt floor each tick is clamped to, so the stack's
                // intrinsic height outgrows the container. Clip to the rail
                // rather than let the tail run off the bottom uncontained.
                .frame(height: geometry.size.height, alignment: .top)
                .clipped()

                if let previewIndex, previewIndex < ticks.count {
                    previewCard(for: ticks[previewIndex])
                        .offset(
                            x: side == .leading ? railHitWidth + Space.x1 : -(previewWidth + Space.x1),
                            y: min(
                                max(0, gap * (CGFloat(previewIndex) + 0.5) - 32),
                                max(0, geometry.size.height - 64)
                            )
                        )
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: previewIndex)
        }
        .frame(width: railHitWidth)
    }

    private func tickButton(_ tick: AIDialTick, hitHeight: CGFloat) -> some View {
        let isActive = tick.id == activeID
        let isHovered = tick.id == hoveredID
        let isEmphasized = isActive || isHovered

        return Button {
            onSelect(tick.id)
        } label: {
            Capsule()
                .fill(palette.foreground)
                .opacity(isEmphasized ? 1 : (tick.isMajor ? 0.7 : 0.25))
                .frame(
                    width: isEmphasized ? Space.step(7) : (tick.isMajor ? Space.x5 : Space.x2_5),
                    height: isEmphasized ? 2 : 1
                )
                .frame(width: railHitWidth, height: hitHeight, alignment: side == .leading ? .leading : .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in hoveredID = hovering ? tick.id : nil }
        #endif
        .accessibilityLabel(tick.label)
        .accessibilityAddTraits(.isButton)
        .animation(.easeOut(duration: 0.15), value: isEmphasized)
    }

    private func previewCard(for tick: AIDialTick) -> some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            Text(tick.author.uppercased())
                .font(theme.typography.sans(theme.typography.xs).smallCaps())
                .foregroundStyle(palette.mutedForeground)
            Text(Self.truncated(tick.label))
                .font(theme.typography.sans(theme.typography.sm))
                .foregroundStyle(palette.cardForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.x3)
        .frame(width: previewWidth, alignment: .leading)
        .background(
            ShadcnTranslucentFill(color: palette.card, cornerRadius: theme.radius.xl)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.xl)
        .shadcnShadow(.lg)
        .allowsHitTesting(false)
    }

    private static func truncated(_ text: String, limit: Int = 180) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<index]) + "…"
    }
}

extension AIDial {
    /// Adapts a transcript into ``AIDialTick``s: user turns anchor the dial as
    /// major stops (the moments worth jumping to), everything else fills in
    /// as minor ticks between them.
    public static func ticks(
        forMessages messages: [(id: AnyHashable, role: AIMessageRole, preview: String)]
    ) -> [AIDialTick] {
        messages.map { message in
            AIDialTick(
                id: message.id,
                label: message.preview,
                isMajor: message.role == .user,
                author: message.role == .user ? "You" : "Assistant"
            )
        }
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
    private let streamToken: AIConversationToken
    private let style: AIConversationStyle

    @State private var pinning = AIConversationPinningState()
    /// Last geometry acted on. Preference changes fire repeatedly with the
    /// same values during a resize, and each one re-ran the bottom pin, which
    /// forces the lazy stack to measure rows again.
    @State private var lastHandledGeometry: AIConversationGeometry?

    private static var bottomAnchorID: String { "ai-conversation-bottom" }

    public init(
        streamToken: AnyHashable = 0,
        style: AIConversationStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.init(token: .opaque(streamToken), style: style, content: content)
    }

    /// Preferred by streaming transcripts: the structured token lets the
    /// conversation pin without animating while only the live tail is growing.
    public init(
        token: AIConversationToken,
        style: AIConversationStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.streamToken = token
        self.style = style
        self.content = content()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Lazy: a plain VStack lays out every message on every
                        // layout pass, so resizing a pane beside a long
                        // transcript re-rendered the whole conversation —
                        // markdown, code blocks and tool cards — each frame.
                        LazyVStack(alignment: .leading, spacing: style.itemSpacing) {
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
                    guard geometry != lastHandledGeometry else { return }
                    lastHandledGeometry = geometry
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
            .onChange(of: streamToken) { previous, next in
                let action = pinning.contentDidChange()
                perform(
                    action,
                    with: proxy,
                    animated: AIConversationToken.animatesFollow(from: previous, to: next))
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
