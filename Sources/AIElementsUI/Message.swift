import ShadcnUI
import SwiftUI

/// Bubble insets for ``AIMessageContent``.
///
/// The standard preset preserves the existing user and attributed-assistant
/// bubble geometry. Apply ``compact`` through ``View/aiMessageStyle(_:)`` when
/// a denser transcript is appropriate.
public struct AIMessageStyle: Equatable, Sendable {
    public var bubbleHorizontalPadding: CGFloat
    public var bubbleVerticalPadding: CGFloat

    public init(
        bubbleHorizontalPadding: CGFloat = 16,
        bubbleVerticalPadding: CGFloat = 12
    ) {
        self.bubbleHorizontalPadding = bubbleHorizontalPadding
        self.bubbleVerticalPadding = bubbleVerticalPadding
    }

    public static let standard = AIMessageStyle()

    public static let compact = AIMessageStyle(bubbleVerticalPadding: 8)
}

private struct AIMessageStyleKey: EnvironmentKey {
    static let defaultValue = AIMessageStyle.standard
}

private struct AIMessageTextSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 15
}

private struct AIAssistantBubbleTintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// Bubble metrics inherited by ``AIMessageContent`` descendants.
    public var aiMessageStyle: AIMessageStyle {
        get { self[AIMessageStyleKey.self] }
        set { self[AIMessageStyleKey.self] = newValue }
    }

    var aiMessageTextSize: CGFloat {
        get { self[AIMessageTextSizeKey.self] }
        set { self[AIMessageTextSizeKey.self] = newValue }
    }

    var aiAssistantBubbleTint: Color? {
        get { self[AIAssistantBubbleTintKey.self] }
        set { self[AIAssistantBubbleTintKey.self] = newValue }
    }
}

extension View {
    /// Applies message bubble metrics to this view hierarchy.
    public func aiMessageStyle(_ style: AIMessageStyle) -> some View {
        environment(\.aiMessageStyle, style)
    }
}

/// Who a message came from. Mirrors `UIMessage["role"]`.
public enum AIMessageRole: String, Sendable, CaseIterable {
    case user
    case assistant
    case system
}

/// AI Elements' `Message` — `max-w-[95%]` column, pushed right for the user.
///
/// The role is published into the environment because the original leans on
/// `group-[.is-user]` to restyle descendants; reading it from the environment
/// is the same idea without the class plumbing.
public struct AIMessage<Content: View>: View {
    private let role: AIMessageRole
    private let content: Content

    public init(_ role: AIMessageRole, @ViewBuilder content: () -> Content) {
        self.role = role
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: role == .user ? .trailing : .leading, spacing: Space.x1_5) {
            content
        }
        .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
        .environment(\.aiMessageRole, role)
    }
}

/// `MessageContent` — a `bg-secondary` bubble for the user, bare text for the
/// assistant.
public struct AIMessageContent<Content: View>: View {
    private let content: Content

    @Environment(\.aiMessageRole) private var role
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.aiMessageStyle) private var messageStyle
    @Environment(\.aiMessageTextSize) private var messageTextSize
    @Environment(\.aiAssistantBubbleTint) private var assistantBubbleTint

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var isUser: Bool { role == .user }

    public var body: some View {
        // `w-fit` — the bubble hugs its text and is pushed to the trailing edge
        // by the spacer, rather than being stretched by a full-width frame.
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: Space.x8) }

            VStack(alignment: .leading, spacing: Space.x2) {
                content
            }
            .font(.system(size: messageTextSize))
            .foregroundStyle(palette.foreground)
            .applyIf(isUser || assistantBubbleTint != nil) { view in
                view
                    .padding(.horizontal, messageStyle.bubbleHorizontalPadding)
                    .padding(.vertical, messageStyle.bubbleVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous)
                            .fill(isUser ? palette.secondary : (assistantBubbleTint ?? .clear))
                    )
            }
            .fixedSize(horizontal: false, vertical: true)
            // A coloured assistant reply hugs a readable column; un-attributed
            // prose keeps AI Elements' traditional bare full-width treatment.
            .applyIf(!isUser && assistantBubbleTint == nil) {
                $0.frame(maxWidth: .infinity, alignment: .leading)
            }

            if !isUser { Spacer(minLength: 0) }
        }
    }
}

extension AIMessageContent where Content == AIResponse {
    /// Convenience for the common case: a markdown body.
    public init(_ markdown: String) {
        self.init { AIResponse(markdown) }
    }
}

/// `MessageActions` — `flex items-center gap-1` strip under a message.
public struct AIMessageActions<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Space.x1) {
            content
        }
    }
}

/// `MessageAction` — a ghost `icon-sm` button with a tooltip.
public struct AIMessageAction: View {
    private let systemImage: String
    private let tooltip: String
    private let action: () -> Void

    public init(systemImage: String, tooltip: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tooltip = tooltip
        self.action = action
    }

    public var body: some View {
        ShadcnButton(icon: systemImage, variant: .ghost, size: .iconXS, action: action)
            .shadcnTooltip(tooltip)
            .accessibilityLabel(tooltip)
    }
}

/// `MessageToolbar` — `mt-4 flex w-full items-center justify-between gap-4`.
public struct AIMessageToolbar<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    public init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Space.x4) {
            leading
            Spacer(minLength: 0)
            trailing
        }
        .padding(.top, Space.x4)
        .frame(maxWidth: .infinity)
    }
}

/// `MessageBranchSelector` — prev / "n of m" / next, welded into a button group.
///
/// Hidden below two branches, matching the original's early return.
public struct AIMessageBranchSelector: View {
    @Binding private var index: Int
    private let total: Int

    public init(index: Binding<Int>, total: Int) {
        self._index = index
        self.total = total
    }

    public var body: some View {
        if total > 1 {
            ShadcnButtonGroup {
                ShadcnButton(
                    icon: ShadcnIcon.chevronLeft,
                    variant: .ghost,
                    size: .iconSM
                ) {
                    index = index > 0 ? index - 1 : total - 1
                }
                .accessibilityLabel("Previous branch")

                ShadcnButtonGroupText("\(index + 1) of \(total)")

                ShadcnButton(
                    icon: ShadcnIcon.chevronRight,
                    variant: .ghost,
                    size: .iconSM
                ) {
                    index = index < total - 1 ? index + 1 : 0
                }
                .accessibilityLabel("Next branch")
            }
        }
    }
}

/// `MessageAttachment` — a `size-24 rounded-lg` tile with a hover-revealed
/// remove button.
public struct AIMessageAttachment: View {
    private let filename: String
    private let image: Image?
    private let onRemove: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false

    public init(filename: String, image: Image? = nil, onRemove: (() -> Void)? = nil) {
        self.filename = filename
        self.image = image
        self.onRemove = onRemove
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        palette.muted
                        ShadcnIconView(ShadcnIcon.paperclip, size: 16)
                            .foregroundStyle(palette.mutedForeground)
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous))

            if let onRemove, isHovering {
                ShadcnButton(icon: ShadcnIcon.xMark, variant: .ghost, size: .iconXS) {
                    onRemove()
                }
                .background(
                    Circle().fill(palette.background.opacity(0.8))
                )
                .padding(Space.x2)
                .transition(.opacity)
                .accessibilityLabel("Remove attachment")
            }
        }
        .frame(width: 96, height: 96)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .shadcnTooltip(filename)
    }
}

/// `MessageAttachments` — right-aligned wrapping tile row.
public struct AIMessageAttachments<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Space.x2) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - Role propagation

private struct AIMessageRoleKey: EnvironmentKey {
    static let defaultValue = AIMessageRole.assistant
}

extension EnvironmentValues {
    /// Role of the enclosing `AIMessage`, standing in for the original's
    /// `.is-user` / `.is-assistant` group classes.
    public var aiMessageRole: AIMessageRole {
        get { self[AIMessageRoleKey.self] }
        set { self[AIMessageRoleKey.self] = newValue }
    }
}
