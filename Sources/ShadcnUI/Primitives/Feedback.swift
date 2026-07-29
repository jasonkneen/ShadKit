import SwiftUI

// MARK: - Separator

/// `bg-border` hairline. Horizontal is `h-px w-full`, vertical `w-px h-full`.
public struct ShadcnSeparator: View {
    private let axis: Axis

    @Environment(\.shadcnPalette) private var palette

    public init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    public var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
            .frame(
                maxWidth: axis == .horizontal ? .infinity : nil,
                maxHeight: axis == .vertical ? .infinity : nil
            )
    }
}

// MARK: - Skeleton

/// `animate-pulse rounded-md bg-accent`.
public struct ShadcnSkeleton: View {
    private let width: CGFloat?
    private let height: CGFloat
    private let cornerRadius: CGFloat?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    public init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat? = nil) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius ?? theme.radius.md, style: .continuous)
            .fill(palette.accent)
            // Tailwind's `animate-pulse` is a 2s ease-in-out 1 -> 0.5 -> 1 cycle.
            .opacity(isDimmed ? 0.5 : 1)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}

// MARK: - Progress

/// `h-2 w-full rounded-full bg-primary/20` with a `bg-primary` indicator.
public struct ShadcnProgress: View {
    private let value: Double

    @Environment(\.shadcnPalette) private var palette

    /// - Parameter value: 0...1. Clamped.
    public init(value: Double) {
        self.value = min(max(value, 0), 1)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.primary.opacity(0.2))
                Capsule()
                    .fill(palette.primary)
                    .frame(width: geometry.size.width * value)
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.2), value: value)
    }
}

// MARK: - Alert

public enum ShadcnAlertVariant: Sendable, CaseIterable {
    case primary
    case destructive
}

/// `rounded-lg border bg-card px-4 py-3 text-sm`, with the icon column shadcn
/// creates via `has-[>svg]:grid-cols-[16px_1fr]`.
public struct ShadcnAlert<Content: View>: View {
    private let variant: ShadcnAlertVariant
    private let systemImage: String?
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        variant: ShadcnAlertVariant = .primary,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.systemImage = systemImage
        self.content = content()
    }

    private var foreground: Color {
        variant == .destructive ? palette.destructive : palette.cardForeground
    }

    public var body: some View {
        HStack(alignment: .top, spacing: systemImage == nil ? 0 : Space.x3) {
            if let systemImage {
                ShadcnIconView(systemImage, size: 16)
                    // `[&>svg]:translate-y-0.5` — nudged to sit on the title baseline.
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: Space.x0_5) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Space.x4)
        .padding(.vertical, Space.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous)
                .fill(palette.card)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.lg)
        .environment(\.shadcnAlertVariant, variant)
    }
}

/// `font-medium tracking-tight`, clamped to one line.
public struct ShadcnAlertTitle: View {
    private let text: String

    @Environment(\.shadcnTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.sm, weight: .medium))
            .tracking(-0.15)
            .lineLimit(1)
            .frame(minHeight: 16, alignment: .leading)
    }
}

/// `text-sm text-muted-foreground` — or `destructive/90` inside a destructive
/// alert, which is what shadcn's `*:data-[slot=alert-description]` rule does.
public struct ShadcnAlertDescription: View {
    private let text: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.shadcnAlertVariant) private var variant

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.sm))
            .foregroundStyle(
                variant == .destructive
                    ? palette.destructive.opacity(0.9)
                    : palette.mutedForeground
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShadcnAlertVariantKey: EnvironmentKey {
    static let defaultValue = ShadcnAlertVariant.primary
}

extension EnvironmentValues {
    var shadcnAlertVariant: ShadcnAlertVariant {
        get { self[ShadcnAlertVariantKey.self] }
        set { self[ShadcnAlertVariantKey.self] = newValue }
    }
}

// MARK: - Avatar

public enum ShadcnAvatarSize: Sendable, CaseIterable {
    case small   // size-6
    case medium  // size-8
    case large   // size-10

    var dimension: CGFloat {
        switch self {
        case .small: 24
        case .medium: 32
        case .large: 40
        }
    }
}

/// `rounded-full overflow-hidden` avatar with a `bg-muted` initials fallback.
public struct ShadcnAvatar: View {
    private let initials: String
    private let size: ShadcnAvatarSize
    private let image: Image?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(initials: String, size: ShadcnAvatarSize = .medium, image: Image? = nil) {
        self.initials = initials
        self.size = size
        self.image = image
    }

    public var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    palette.muted
                    Text(initials)
                        .font(
                            theme.typography.sans(
                                size == .small ? theme.typography.xs : theme.typography.sm
                            )
                        )
                        .foregroundStyle(palette.mutedForeground)
                }
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
    }
}
