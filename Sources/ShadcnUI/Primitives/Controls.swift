import SwiftUI

// MARK: - Switch

public enum ShadcnSwitchSize: Sendable {
    case medium  // h-[1.15rem] w-8
    case small   // h-3.5 w-6

    var track: CGSize {
        switch self {
        case .medium: CGSize(width: 32, height: 18.4)
        case .small: CGSize(width: 24, height: 14)
        }
    }

    var thumb: CGFloat {
        switch self {
        case .medium: 16
        case .small: 12
        }
    }
}

/// Radix `Switch` — `rounded-full`, `bg-primary` when on, `bg-input` when off.
public struct ShadcnSwitch: View {
    @Binding private var isOn: Bool
    private let size: ShadcnSwitchSize

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init(isOn: Binding<Bool>, size: ShadcnSwitchSize = .medium) {
        self._isOn = isOn
        self.size = size
    }

    private var trackColor: Color {
        if isOn { return palette.primary }
        // dark:data-[state=unchecked]:bg-input/80
        return palette.isDark ? palette.input.opacity(0.8) : palette.input
    }

    private var thumbColor: Color {
        // dark:data-[state=checked]:bg-primary-foreground / unchecked:bg-foreground
        guard palette.isDark else { return palette.background }
        return isOn ? palette.primaryForeground : palette.foreground
    }

    public var body: some View {
        let inset = (size.track.height - size.thumb) / 2
        let travel = size.track.width - size.thumb - inset * 2

        Capsule()
            .fill(trackColor)
            .frame(width: size.track.width, height: size.track.height)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(thumbColor)
                    .frame(width: size.thumb, height: size.thumb)
                    .padding(.leading, inset)
                    .offset(x: isOn ? travel : 0)
            }
            .shadcnShadow(.xs)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
            .onTapGesture {
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.18)) { isOn.toggle() }
            }
    }
}

// MARK: - Checkbox

/// Radix `Checkbox` — `size-4 rounded-[4px] border-input`, filling with
/// `primary` when checked.
public struct ShadcnCheckbox: View {
    @Binding private var isChecked: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init(isChecked: Binding<Bool>) {
        self._isChecked = isChecked
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isChecked ? palette.primary : (palette.isDark ? palette.input.opacity(0.3) : .clear))
            .frame(width: 16, height: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(isChecked ? palette.primary : palette.input, lineWidth: 1)
            )
            .overlay {
                if isChecked {
                    Image(systemName: ShadcnIcon.check)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(palette.primaryForeground)
                }
            }
            .shadcnShadow(.xs)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.12)) { isChecked.toggle() }
            }
    }
}

// MARK: - Tabs

public enum ShadcnTabsVariant: Sendable {
    /// `bg-muted` pill container with a raised active tab.
    case solid
    /// Transparent container with an underline on the active tab.
    case line
}

/// Radix `Tabs` list. Content switching is left to the caller so this works
/// with any selection type.
public struct ShadcnTabs<Value: Hashable>: View {
    private let items: [(value: Value, label: String)]
    @Binding private var selection: Value
    private let variant: ShadcnTabsVariant

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Namespace private var indicator

    public init(
        selection: Binding<Value>,
        variant: ShadcnTabsVariant = .solid,
        items: [(value: Value, label: String)]
    ) {
        self._selection = selection
        self.variant = variant
        self.items = items
    }

    public var body: some View {
        HStack(spacing: variant == .line ? Space.x1 : 0) {
            ForEach(items, id: \.value) { item in
                tab(for: item)
            }
        }
        .padding(variant == .solid ? 3 : 0)
        .frame(height: 36)
        .background {
            if variant == .solid {
                RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous)
                    .fill(palette.muted)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func tab(for item: (value: Value, label: String)) -> some View {
        let isActive = item.value == selection

        Button {
            withAnimation(.easeOut(duration: 0.18)) { selection = item.value }
        } label: {
            Text(item.label)
                .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                .foregroundStyle(isActive ? palette.foreground : palette.foreground.opacity(0.6))
                .padding(.horizontal, Space.x2)
                .frame(maxHeight: .infinity)
                .background {
                    if isActive {
                        switch variant {
                        case .solid:
                            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                                .fill(palette.background)
                                .shadcnShadow(.sm)
                                .matchedGeometryEffect(id: "tab", in: indicator)
                        case .line:
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(palette.foreground)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "tab", in: indicator)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.shadcnBare)
    }
}

// MARK: - Button group

/// shadcn's `ButtonGroup` — buttons welded into one control, with only the
/// outer corners rounded.
public struct ShadcnButtonGroup<Content: View>: View {
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.isDark ? palette.input.opacity(0.3) : palette.background)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous))
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// `ButtonGroupText` — a non-interactive label wedged into a button group, used
/// for AI Elements' "1 of 3" branch counter.
public struct ShadcnButtonGroupText: View {
    private let text: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.sm, weight: .medium))
            .foregroundStyle(palette.mutedForeground)
            .padding(.horizontal, Space.x2)
            .frame(height: 32)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
