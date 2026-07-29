import SwiftUI

/// The six `badgeVariants` from shadcn/ui.
public enum ShadcnBadgeVariant: Sendable, CaseIterable {
    case primary
    case secondary
    case destructive
    case outline
    case ghost
    case link
}

/// `rounded-full border px-2 py-0.5 text-xs font-medium` pill.
public struct ShadcnBadge<Content: View>: View {
    private let variant: ShadcnBadgeVariant
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        variant: ShadcnBadgeVariant = .primary,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.content = content()
    }

    private var foreground: Color {
        switch variant {
        case .primary: palette.primaryForeground
        case .secondary: palette.secondaryForeground
        case .destructive: palette.destructiveForeground
        case .outline: palette.foreground
        case .ghost: palette.foreground
        case .link: palette.primary
        }
    }

    private var background: Color {
        switch variant {
        case .primary: palette.primary
        case .secondary: palette.secondary
        // dark:bg-destructive/60
        case .destructive: palette.isDark ? palette.destructive.opacity(0.6) : palette.destructive
        case .outline, .ghost, .link: .clear
        }
    }

    /// Only `outline` shows a border; the rest use `border-transparent`.
    private var borderColor: Color {
        variant == .outline ? palette.border : .clear
    }

    public var body: some View {
        HStack(spacing: Space.x1) {
            content
        }
        .font(theme.typography.sans(theme.typography.xs, weight: .medium))
        .foregroundStyle(foreground)
        .lineLimit(1)
        .padding(.horizontal, Space.x2)
        .padding(.vertical, Space.x0_5)
        .background(
            Capsule(style: .continuous).fill(background)
        )
        .overlay(
            Capsule(style: .continuous).strokeBorder(borderColor, lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
        .environment(\.shadcnIconSize, 12)
        .fixedSize(horizontal: true, vertical: false)
    }
}

extension ShadcnBadge where Content == Text {
    public init(_ title: String, variant: ShadcnBadgeVariant = .primary) {
        self.init(variant: variant) { Text(title) }
    }
}

extension ShadcnBadge where Content == ShadcnBadgeIconLabel {
    /// Icon + text pill, as used by `ToolHeader`'s status badge.
    public init(_ title: String, systemImage: String, variant: ShadcnBadgeVariant = .primary) {
        self.init(variant: variant) {
            ShadcnBadgeIconLabel(title: title, systemImage: systemImage, tint: nil)
        }
    }

    /// Icon + text pill where the icon carries its own colour, matching the
    /// `text-green-600` / `text-red-600` status icons in AI Elements.
    public init(
        _ title: String,
        systemImage: String,
        iconTint: Color,
        variant: ShadcnBadgeVariant = .primary
    ) {
        self.init(variant: variant) {
            ShadcnBadgeIconLabel(title: title, systemImage: systemImage, tint: iconTint)
        }
    }
}

public struct ShadcnBadgeIconLabel: View {
    let title: String
    let systemImage: String
    /// `nil` inherits the badge's foreground colour.
    let tint: Color?

    public var body: some View {
        let icon = ShadcnIconView(systemImage, size: 12)
        if let tint {
            icon.foregroundStyle(tint)
        } else {
            icon
        }
        Text(title)
    }
}
