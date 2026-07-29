import SwiftUI

/// `rounded-xl border bg-card py-6 shadow-sm` with a 24pt stack gap.
///
/// Section padding is horizontal-only because the card supplies the vertical
/// padding, exactly as shadcn's `py-6` + `px-6` split does.
public struct ShadcnCard<Content: View>: View {
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x6) {
            content
        }
        .padding(.vertical, Space.x6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(palette.card)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.xl)
        .foregroundStyle(palette.cardForeground)
        .shadcnShadow(.sm)
    }
}

/// `px-6` header holding a title, description and optional trailing action.
public struct ShadcnCardHeader<Content: View, Action: View>: View {
    private let content: Content
    private let action: Action

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) {
        self.content = content()
        self.action = action()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Space.x4) {
            VStack(alignment: .leading, spacing: Space.x1_5) {
                content
            }
            Spacer(minLength: 0)
            action
        }
        .padding(.horizontal, Space.x6)
    }
}

extension ShadcnCardHeader where Action == EmptyView {
    public init(@ViewBuilder content: () -> Content) {
        self.init(content: content, action: { EmptyView() })
    }
}

/// `leading-none font-semibold`.
public struct ShadcnCardTitle: View {
    private let text: String

    @Environment(\.shadcnTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.base, weight: .semibold))
    }
}

/// `text-sm text-muted-foreground`.
public struct ShadcnCardDescription: View {
    private let text: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.sm))
            .foregroundStyle(palette.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// `px-6` body section.
public struct ShadcnCardContent<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.x6)
    }
}

/// `flex items-center px-6` footer.
public struct ShadcnCardFooter<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Space.x2) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.x6)
    }
}
