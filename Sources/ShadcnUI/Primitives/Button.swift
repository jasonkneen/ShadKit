import SwiftUI

/// The six `buttonVariants` shadcn ships.
public enum ShadcnButtonVariant: Sendable, CaseIterable {
    case primary
    case destructive
    case outline
    case secondary
    case ghost
    case link
}

/// The eight `size` values from `buttonVariants`.
public enum ShadcnButtonSize: Sendable, CaseIterable {
    case medium   // `default` — h-9 px-4
    case xs       // h-6 px-2 text-xs
    case small    // h-8 px-3
    case large    // h-10 px-6
    case icon     // size-9
    case iconXS   // size-6
    case iconSM   // size-8
    case iconLG   // size-10

    /// Fixed height. Icon sizes are square at this value.
    var height: CGFloat {
        switch self {
        case .medium: 36
        case .xs: 24
        case .small: 32
        case .large: 40
        case .icon: 36
        case .iconXS: 24
        case .iconSM: 32
        case .iconLG: 40
        }
    }

    var isIconOnly: Bool {
        switch self {
        case .icon, .iconXS, .iconSM, .iconLG: true
        default: false
        }
    }

    /// Horizontal padding with no leading icon.
    var horizontalPadding: CGFloat {
        switch self {
        case .medium: Space.x4
        case .xs: Space.x2
        case .small: Space.x3
        case .large: Space.x6
        default: 0
        }
    }

    /// shadcn's `has-[>svg]:px-*` — padding tightens when an icon is present.
    var horizontalPaddingWithIcon: CGFloat {
        switch self {
        case .medium: Space.x3
        case .xs: Space.x1_5
        case .small: Space.x2_5
        case .large: Space.x4
        default: 0
        }
    }

    var gap: CGFloat {
        switch self {
        case .xs: Space.x1
        case .small: Space.x1_5
        default: Space.x2
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .xs, .iconXS: 12
        default: 16
        }
    }

    var isSmallText: Bool {
        switch self {
        case .xs, .iconXS: true
        default: false
        }
    }
}

/// A `ButtonStyle` that reproduces `buttonVariants` from shadcn/ui.
///
/// Works on any `Button`:
/// ```swift
/// Button("Send") { }.buttonStyle(.shadcn(.primary))
/// ```
public struct ShadcnButtonStyle: ButtonStyle {
    var variant: ShadcnButtonVariant
    var size: ShadcnButtonSize
    /// Set when the label leads with an icon, so padding matches
    /// `has-[>svg]:px-*`.
    var hasIcon: Bool
    /// Overrides the derived corner radius — used by grouped controls.
    var cornerRadius: CGFloat?
    /// Lets a caller stretch the button, as `w-full` would.
    var fillsWidth: Bool

    public init(
        variant: ShadcnButtonVariant = .primary,
        size: ShadcnButtonSize = .medium,
        hasIcon: Bool = false,
        cornerRadius: CGFloat? = nil,
        fillsWidth: Bool = false
    ) {
        self.variant = variant
        self.size = size
        self.hasIcon = hasIcon
        self.cornerRadius = cornerRadius
        self.fillsWidth = fillsWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        ShadcnButtonBody(
            configuration: configuration,
            variant: variant,
            size: size,
            hasIcon: hasIcon,
            cornerRadiusOverride: cornerRadius,
            fillsWidth: fillsWidth
        )
    }
}

private struct ShadcnButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let variant: ShadcnButtonVariant
    let size: ShadcnButtonSize
    let hasIcon: Bool
    let cornerRadiusOverride: CGFloat?
    let fillsWidth: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var cornerRadius: CGFloat { cornerRadiusOverride ?? theme.radius.md }

    /// Hover is only "live" when the control can actually be clicked.
    private var isHot: Bool { isHovering && isEnabled }

    private var font: Font {
        theme.typography.sans(
            size.isSmallText ? theme.typography.xs : theme.typography.sm,
            weight: .medium
        )
    }

    private var foreground: Color {
        switch variant {
        case .primary: palette.primaryForeground
        case .destructive: palette.destructiveForeground
        case .outline: isHot ? palette.accentForeground : palette.foreground
        case .secondary: palette.secondaryForeground
        case .ghost: isHot ? palette.accentForeground : palette.foreground
        case .link: palette.primary
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch variant {
        case .primary:
            shape.fill(palette.primary.opacity(isHot ? 0.9 : 1))
        case .destructive:
            // dark:bg-destructive/60
            let base = palette.isDark ? palette.destructive.opacity(0.6) : palette.destructive
            shape.fill(base.opacity(isHot ? 0.9 : 1))
        case .outline:
            if palette.isDark {
                // dark:bg-input/30 hover:bg-input/50
                shape.fill(palette.input.opacity(isHot ? 0.5 : 0.3))
            } else {
                shape.fill(isHot ? palette.accent : palette.background)
            }
        case .secondary:
            shape.fill(palette.secondary.opacity(isHot ? 0.8 : 1))
        case .ghost:
            // dark:hover:bg-accent/50
            shape.fill(isHot ? palette.accent.opacity(palette.isDark ? 0.5 : 1) : .clear)
        case .link:
            Color.clear
        }
    }

    private var horizontalPadding: CGFloat {
        guard !size.isIconOnly else { return 0 }
        return hasIcon ? size.horizontalPaddingWithIcon : size.horizontalPadding
    }

    var body: some View {
        configuration.label
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .frame(height: size.height)
            .frame(width: size.isIconOnly ? size.height : nil)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(background)
            .applyIf(variant == .outline) { view in
                view.shadcnBorder(
                    palette.isDark ? palette.input : palette.border,
                    cornerRadius: cornerRadius
                )
            }
            .applyIf(variant == .outline) { $0.shadcnShadow(.xs) }
            .applyIf(variant == .link && isHot) { $0.underline() }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .environment(\.shadcnIconSize, size.iconSize)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ShadcnButtonStyle {
    /// `Button("Save") { }.buttonStyle(.shadcn(.primary))`
    public static func shadcn(
        _ variant: ShadcnButtonVariant = .primary,
        size: ShadcnButtonSize = .medium,
        hasIcon: Bool = false,
        fillsWidth: Bool = false
    ) -> ShadcnButtonStyle {
        ShadcnButtonStyle(
            variant: variant,
            size: size,
            hasIcon: hasIcon,
            fillsWidth: fillsWidth
        )
    }
}

// MARK: - Icon sizing

private struct ShadcnIconSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 16
}

extension EnvironmentValues {
    /// Size that `ShadcnIconView` uses when a container dictates it — set by
    /// buttons so `[&_svg]:size-4` behaviour comes for free.
    public var shadcnIconSize: CGFloat {
        get { self[ShadcnIconSizeKey.self] }
        set { self[ShadcnIconSizeKey.self] = newValue }
    }
}

// MARK: - Convenience view

/// A shadcn button with the common label shapes pre-built.
public struct ShadcnButton<Label: View>: View {
    private let variant: ShadcnButtonVariant
    private let size: ShadcnButtonSize
    private let hasIcon: Bool
    private let fillsWidth: Bool
    private let action: () -> Void
    private let label: Label

    public init(
        variant: ShadcnButtonVariant = .primary,
        size: ShadcnButtonSize = .medium,
        hasIcon: Bool = false,
        fillsWidth: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.hasIcon = hasIcon
        self.fillsWidth = fillsWidth
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) { label }
            .buttonStyle(
                ShadcnButtonStyle(
                    variant: variant,
                    size: size,
                    hasIcon: hasIcon,
                    fillsWidth: fillsWidth
                )
            )
    }
}

extension ShadcnButton where Label == Text {
    /// Text-only button.
    public init(
        _ title: String,
        variant: ShadcnButtonVariant = .primary,
        size: ShadcnButtonSize = .medium,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            variant: variant,
            size: size,
            hasIcon: false,
            fillsWidth: fillsWidth,
            action: action
        ) {
            Text(title)
        }
    }
}

extension ShadcnButton where Label == ShadcnButtonIconLabel {
    /// Icon + text, with the tighter `has-[>svg]` padding applied.
    public init(
        _ title: String,
        systemImage: String,
        variant: ShadcnButtonVariant = .primary,
        size: ShadcnButtonSize = .medium,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            variant: variant,
            size: size,
            hasIcon: true,
            fillsWidth: fillsWidth,
            action: action
        ) {
            ShadcnButtonIconLabel(title: title, systemImage: systemImage, gap: size.gap)
        }
    }

    /// Icon-only button. Pass one of the `icon*` sizes.
    public init(
        icon systemImage: String,
        variant: ShadcnButtonVariant = .ghost,
        size: ShadcnButtonSize = .icon,
        action: @escaping () -> Void
    ) {
        self.init(variant: variant, size: size, hasIcon: true, action: action) {
            ShadcnButtonIconLabel(title: nil, systemImage: systemImage, gap: size.gap)
        }
    }
}

/// Label used by the icon-bearing `ShadcnButton` initialisers.
public struct ShadcnButtonIconLabel: View {
    let title: String?
    let systemImage: String
    let gap: CGFloat

    @Environment(\.shadcnIconSize) private var iconSize

    public var body: some View {
        HStack(spacing: title == nil ? 0 : gap) {
            ShadcnIconView(systemImage, size: iconSize)
            if let title {
                Text(title)
            }
        }
    }
}
